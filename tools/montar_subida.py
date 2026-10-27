"""Monta o roteiro de subida (deploy/subida_relatorio_2026-10-26.sql) a partir do código do projeto.

O roteiro é só a ordem de execução: cada bloco é o conteúdo de um arquivo gerado (deploy/criar_*.sql,
deploy/descrever_*.sql) ou de uma validação (sql/validacoes/*.sql), sem o cabeçalho de comentários. Nada é escrito à
mão aqui além dos títulos dos blocos, das permissões e da coluna nova da SLA. Se um SELECT, esquema ou validação
mudar: python tools/gerar_deploy.py e depois python tools/montar_subida.py.

Ordem: (1) coluna nova da SLA e descrições; (2) cada tabela nova, criada já com os dados de hoje, seguida da sua
validação, na ordem de TABELAS_PRODUCAO do job (cada validação lê as anteriores); (3) permissão de escrita da conta do
job nas tabelas novas; (4) cada view, na ordem do cadastro VIEWS, seguida da sua validação. Depois, no Cloud Shell, o
deploy do job (deploy/gcp_setup.md, passo 4).
"""
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "tools"))
from gerar_deploy import DATASET, PROJETO_GCP, TABELAS, VIEWS  # noqa: E402

DESTINO = RAIZ / "deploy" / "subida_relatorio_2026-10-26.sql"
CONTA_JOB = f"serviceAccount:gold-agenciamento@{PROJETO_GCP}.iam.gserviceaccount.com"

# tabelas já em produção (não são recriadas: o criar_ apagaria a permissão do job)
EM_PRODUCAO = ["gld_agenciamento_2026_sla_movimentos", "gld_agenciamento_entrada_diaria", "gld_agenciamento_fluxo_mensal"]
SLA = "gld_agenciamento_2026_sla_movimentos"
SLA_COLUNAS_NOVAS = [("sla_sem_almoco_horas", "FLOAT64", "R24, sem almoço")]

# grão de cada objeto novo, para o título do bloco
GRAO = {
    "gld_agenciamento_2026_talentos_ano": "ano × categoria",
    "gld_agenciamento_2026_talentos_ranking": "recorte × talento × mês",
    "gld_agenciamento_2026_saidas_status": "mês × status",
    "gld_agenciamento_2026_previsao_exclusividade_diaria": "dia × tipo",
    "gld_agenciamento_2026_previsao_lotes": "dia × recorte",
    "gld_agenciamento_2026_previsao_exclusividade_mensal": "mês × tipo",
    "gld_agenciamento_2026_previsao_exclusividade_mensal_inbound": "mês",
    "gld_agenciamento_2026_previsao_exclusividade_mensal_mercado": "mês",
    "gld_agenciamento_2026_sla_entregas": "orçamento entregue",
    "gld_agenciamento_2026_sla_entregas_status": "orçamento × status",
    "gld_agenciamento_fila_mensal": "mês × mês de entrada",
    "gld_agenciamento_atendimento_mensal": "mês",
    "gld_agenciamento_previsao_mensal": "mês × tipo",
}

LINHA = "-- " + "=" * 108


def ordem_do_job() -> list[str]:
    texto = (RAIZ / "job" / "main.py").read_text(encoding="utf-8")
    lista = re.search(r"TABELAS_PRODUCAO = \[(.*?)\]", texto, re.S).group(1)
    return re.findall(r'"([^"]+)"', lista)


def sem_cabecalho(caminho: Path) -> str:
    """Conteúdo do arquivo sem os comentários e linhas vazias do início."""
    linhas = caminho.read_text(encoding="utf-8").splitlines()
    while linhas and (not linhas[0].strip() or linhas[0].lstrip().startswith("--")):
        linhas.pop(0)
    corpo = "\n".join(linhas).rstrip()
    return corpo if corpo.endswith(";") else corpo + ";"


def curto(nome: str) -> str:
    return nome.replace("gld_agenciamento_2026_", "").replace("gld_agenciamento_", "")


def referencias(validacao: Path, propria: str) -> list[str]:
    texto = validacao.read_text(encoding="utf-8")
    achados = re.findall(rf"`{re.escape(PROJETO_GCP)}\.{DATASET}\.(gld_\w+)`", texto)
    return list(dict.fromkeys(a for a in achados if a != propria))


def titulo(n: int, texto: str, detalhe: str = "") -> str:
    linhas = [LINHA, f"-- BLOCO {n} — {texto}"] + ([f"-- {detalhe}"] if detalhe else []) + [LINHA]
    return "\n".join(linhas)


def titulo_validacao(n: int, nome: str, arquivo: Path) -> str:
    refs = referencias(arquivo, nome)
    contra = f" (confere contra: {', '.join(curto(r) for r in refs)})" if refs else ""
    return f"-- BLOCO {n} — validação de {nome}{contra}"


def montar() -> str:
    novas = [t for t in ordem_do_job() if t not in EM_PRODUCAO]
    faltando = [t for t in novas if t not in TABELAS]
    if faltando:
        raise SystemExit(f"fora do cadastro TABELAS do gerar_deploy.py: {faltando}")

    partes, n = [], 0
    cab = (
        "-- Roteiro de subida das golds do relatório. GERADO por tools/montar_subida.py a partir de deploy/ e\n"
        "-- sql/validacoes/ (não editar à mão): se um SELECT, esquema ou validação mudar, rode\n"
        "-- python tools/gerar_deploy.py e python tools/montar_subida.py.\n"
        f"-- Executar no console do BigQuery, conta caio.barroso@viu.com.br, projeto {PROJETO_GCP}, UM BLOCO POR VEZ,\n"
        "-- conferindo a saída. Validação: toda linha com ok = true; parar se alguma vier false.\n"
        "-- Depois de 28/10/2026 (reunião). Antes do 1º bloco: commit/push (deploy/gcp_setup.md).\n"
        "-- Depois do último bloco: deploy do job com as tabelas novas em TABELAS, ensaio --dry-run e execução real\n"
        "-- (deploy/gcp_setup.md, passo 4). Até lá as tabelas novas ficam com os dados do dia da criação e as views de\n"
        "-- entregas da SLA com horas zero (a coluna R24 só é preenchida pelo job novo)."
    )
    partes.append(cab)

    nome_sla = f"`{PROJETO_GCP}.{DATASET}.{SLA}`"
    for coluna, tipo, regra in SLA_COLUNAS_NOVAS:
        n += 1
        partes.append(titulo(n, f"SLA: coluna nova {coluna} ({regra}). NÃO usar o criar_ da SLA (recriaria a tabela e "
                                "apagaria a permissão).", "A coluna fica vazia até a próxima execução do job com o código novo."))
        partes.append(f"ALTER TABLE {nome_sla}\n  ADD COLUMN IF NOT EXISTS {coluna} {tipo};")
    n += 1
    partes.append(f"-- BLOCO {n} — SLA: descrições (tabela e colunas, inclusive a nova)")
    partes.append(sem_cabecalho(RAIZ / "deploy" / f"descrever_{SLA}.sql"))

    for t in novas:
        n += 1
        partes.append(titulo(n, f"TABELA {t} (uma linha por {GRAO.get(t, '?')}). Cria já com os dados de hoje."))
        partes.append(sem_cabecalho(RAIZ / "deploy" / f"criar_{t}.sql"))
        n += 1
        validacao = RAIZ / "sql" / "validacoes" / f"{t}.sql"
        partes.append(titulo_validacao(n, t, validacao))
        partes.append(sem_cabecalho(validacao))

    n += 1
    partes.append(titulo(n, "PERMISSÕES: escrita da conta do job (gold-agenciamento) em cada tabela nova.",
                         "Views não precisam. Recriar uma tabela pelo criar_ apaga esta permissão: rodar de novo."))
    partes.append("\n".join(
        f"GRANT `roles/bigquery.dataEditor` ON TABLE `{PROJETO_GCP}.{DATASET}.{t}` TO \"{CONTA_JOB}\";" for t in novas))

    for v in VIEWS:
        n += 1
        partes.append(titulo(n, f"VIEW {v} (uma linha por {GRAO.get(v, '?')}). Não guarda dados; sempre igual à base."))
        partes.append(sem_cabecalho(RAIZ / "deploy" / f"criar_{v}.sql"))
        validacao = RAIZ / "sql" / "validacoes" / f"{v}.sql"
        if validacao.exists():
            n += 1
            partes.append(titulo_validacao(n, v, validacao))
            partes.append(sem_cabecalho(validacao))

    return "\n\n".join(partes) + "\n"


if __name__ == "__main__":
    DESTINO.write_text(montar(), encoding="utf-8")
    print(DESTINO.relative_to(RAIZ))

"""Job gold-agenciamento: atualiza as tabelas gold do Agenciamento 2026 a partir das silvers.

Tudo ou nada para o conjunto de TABELAS:
  1. confere que as silvers de origem foram processadas hoje (espera até ESPERA_SILVER_MIN minutos);
  2. calcula cada tabela nova numa tabela temporária da mesma sessão (sql/<tabela>.sql);
  3. roda a validação de cada uma (sql/validacoes/<tabela>.sql) sobre a tabela nova; qualquer ok = FALSE para sem
     gravar nenhuma;
  4. só com todas validadas, troca o conteúdo de todas as tabelas de destino numa única transação (DELETE + INSERT),
     mantendo esquema e descrições.

As tabelas de destino precisam existir (criadas uma vez por deploy/criar_<tabela>.sql).
Uso: python job/main.py [--dry-run]   (dry-run faz 1–3 e não grava)
Sai com código 1 em qualquer falha (o Cloud Run marca a execução como falha e o alerta avisa).
"""

import csv
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

from google.cloud import bigquery

RAIZ = Path(__file__).resolve().parent.parent
FUSO = ZoneInfo("America/Sao_Paulo")

PROJETO = os.environ.get("GCP_PROJECT_ID", "gglobo-viu-dados-hdg-prd")
LOCAL = os.environ.get("BQ_LOCATION", "US")
DATASET_GOLD = os.environ.get("BQ_DATASET_GOLD", "gold_monday")
# tabelas que a produção deve atualizar; TABELAS diferente disso gera aviso no log (proteção contra um deploy com a
# lista desatualizada, que tiraria uma tabela da atualização sem falhar)
# A ordem importa: a validação de uma tabela pode conferir contra outra já calculada nesta execução (o fluxo mensal
# confere contra a entrada diária), então a de referência vem antes. Conferências: talentos_ano → diária;
# talentos_ranking → talentos_ano; saidas_status → fluxo; previsao_exclusividade_diaria → diária e talentos_ano;
# previsao_lotes → previsao_exclusividade_diaria. As views (cadastro VIEWS do tools/gerar_deploy.py) não entram aqui
TABELAS_PRODUCAO = ["gld_agenciamento_2026_sla_movimentos", "gld_agenciamento_entrada_diaria",
                    "gld_agenciamento_fluxo_mensal", "gld_agenciamento_2026_talentos_ano",
                    "gld_agenciamento_2026_talentos_ranking", "gld_agenciamento_2026_saidas_status",
                    "gld_agenciamento_2026_previsao_exclusividade_diaria", "gld_agenciamento_2026_previsao_lotes"]
TABELAS = [t.strip() for t in os.environ.get("TABELAS", ",".join(TABELAS_PRODUCAO)).split(",") if t.strip()]
# silvers diárias que precisam ser de hoje; as de carga única (slv_agenciamento_2024_itens e _2025_itens) ficam fora
FONTES = [
    "silver_monday.slv_agenciamento_2026_itens",
    "silver_monday.slv_agenciamento_2026_log",
]
EXIGIR_SILVER_DO_DIA = os.environ.get("EXIGIR_SILVER_DO_DIA", "true").lower() == "true"
ESPERA_SILVER_MIN = int(os.environ.get("ESPERA_SILVER_MIN", "30"))
DRY_RUN = "--dry-run" in sys.argv or os.environ.get("DRY_RUN", "false").lower() == "true"
LABELS = {"projeto": "ppd-golden-agenciamento-monday", "job": "gold-agenciamento", "camada": "gold"}


class FalhaJob(Exception):
    pass


def log(severidade: str, mensagem: str, **campos) -> None:
    """Log estruturado (o Cloud Logging lê o JSON e a severidade)."""
    print(json.dumps({"severity": severidade, "message": mensagem, **campos}, ensure_ascii=False, default=str), flush=True)


def config(**extra) -> bigquery.QueryJobConfig:
    return bigquery.QueryJobConfig(labels=LABELS, **extra)


def silver_do_dia(cliente: bigquery.Client) -> dict:
    """Data (Brasília) do último processamento de cada silver de origem."""
    partes = [
        f"SELECT '{f}' AS fonte, MAX(DATE(_processado_em, 'America/Sao_Paulo')) AS dia FROM `{PROJETO}.{f}`"
        for f in FONTES
    ]
    linhas = cliente.query(" UNION ALL ".join(partes), job_config=config()).result()
    return {l["fonte"]: l["dia"] for l in linhas}


def esperar_silver(cliente: bigquery.Client) -> None:
    hoje = datetime.now(FUSO).date()
    limite = time.monotonic() + ESPERA_SILVER_MIN * 60
    while True:
        dias = silver_do_dia(cliente)
        atrasadas = {f: d for f, d in dias.items() if d != hoje}
        if not atrasadas:
            log("INFO", "silver do dia ok", hoje=hoje, fontes=dias)
            return
        if time.monotonic() >= limite:
            raise FalhaJob(f"silver de hoje ({hoje}) não chegou em {ESPERA_SILVER_MIN} min: {atrasadas}")
        log("INFO", "aguardando a silver do dia", hoje=hoje, atrasadas=atrasadas)
        time.sleep(120)


def colunas(tabela: str) -> list[str]:
    with (RAIZ / "sql" / "esquemas" / f"{tabela}.csv").open(encoding="utf-8", newline="") as f:
        return [c["coluna"] for c in csv.DictReader(f)]


def destino(tabela: str) -> str:
    return f"`{PROJETO}.{DATASET_GOLD}.{tabela}`"


def calcular_e_validar(cliente: bigquery.Client, na_sessao: bigquery.QueryJobConfig, tabela: str,
                       calculadas: list[str]) -> dict:
    """Cria a tabela nova (novo_<tabela>) na sessão e roda a validação sobre ela; qualquer ok = FALSE é falha.
    Se a validação lê outra tabela gold do projeto, lê a versão desta execução (novo_<outra>), que precisa estar em
    `calculadas` — senão compararia o cálculo de hoje com a carga anterior."""
    select = (RAIZ / "sql" / f"{tabela}.sql").read_text(encoding="utf-8").rstrip().rstrip(";")
    validacao = (RAIZ / "sql" / "validacoes" / f"{tabela}.sql").read_text(encoding="utf-8")
    if destino(tabela) not in validacao:
        raise FalhaJob(f"{tabela}: a validação não lê {destino(tabela)}")
    novo = f"novo_{tabela}"
    referencias = [t for t in TABELAS_PRODUCAO if t != tabela and destino(t) in validacao]
    faltando = [t for t in referencias if t not in calculadas]
    if faltando:
        raise FalhaJob(f"{tabela}: a validação confere contra {faltando}, que precisa vir antes em TABELAS")

    cliente.query(f"CREATE TEMP TABLE {novo} AS\n{select}", job_config=na_sessao).result()
    texto = validacao.replace(destino(tabela), novo)
    for t in referencias:
        texto = texto.replace(destino(t), f"novo_{t}")
    resultado = list(cliente.query(texto, job_config=na_sessao).result())
    falhas = [dict(l) for l in resultado if not l["ok"]]
    for l in resultado:
        # esperado = 'aviso': não bloqueia, mas vai ao log como WARNING quando há o que avisar
        aviso = l["esperado"] == "aviso" and l["resultado"] not in (None, "", "0")
        log("ERROR" if not l["ok"] else "WARNING" if aviso else "INFO", "validação", tabela=tabela,
            verificacao=l["verificacao"], resultado=l["resultado"], esperado=l["esperado"], ok=l["ok"])
    if falhas:
        raise FalhaJob(f"{tabela}: {len(falhas)} validação(ões) falharam; nada gravado em nenhuma tabela")

    # projetos só nas tabelas com projeto_id (a entrada diária, por exemplo, é por dia)
    contagem = "COUNT(*) AS linhas" + (
        ", COUNT(DISTINCT projeto_id) AS projetos" if "projeto_id" in colunas(tabela) else "")
    resumo = dict(next(iter(cliente.query(f"SELECT {contagem} FROM {novo}", job_config=na_sessao).result())))
    log("INFO", "tabela validada", tabela=tabela, **resumo)
    return resumo


def atualizar(cliente: bigquery.Client, tabelas: list[str]) -> dict:
    """Tudo ou nada: calcula e valida todas as tabelas na mesma sessão; só então troca o conteúdo de todas numa
    única transação (esquema e descrições das tabelas de destino ficam)."""
    abrir = cliente.query("SELECT 1", job_config=config(create_session=True))
    abrir.result()
    na_sessao = config(connection_properties=[bigquery.ConnectionProperty("session_id", abrir.session_info.session_id)])
    try:
        resumos = {}
        for t in tabelas:
            resumos[t] = calcular_e_validar(cliente, na_sessao, t, list(resumos))
        if DRY_RUN:
            log("INFO", "DRY_RUN: nada gravado", resumos=resumos)
            return resumos

        trocas = []
        for t in tabelas:
            lista = ", ".join(colunas(t))
            trocas.append(f"DELETE FROM {destino(t)} WHERE TRUE;\n"
                          f"INSERT INTO {destino(t)} ({lista})\nSELECT {lista} FROM novo_{t};")
        # erro no meio da transação: ROLLBACK explícito (não deixa a transação aberta na sessão) e o erro sobe
        cliente.query(
            "BEGIN\n"
            "  BEGIN TRANSACTION;\n" + "\n".join(trocas) + "\n  COMMIT TRANSACTION;\n"
            "EXCEPTION WHEN ERROR THEN\n"
            "  ROLLBACK TRANSACTION;\n"
            "  RAISE USING MESSAGE = @@error.message;\n"
            "END;",
            job_config=na_sessao,
        ).result()
        log("INFO", "tabelas atualizadas", resumos=resumos)
        return resumos
    finally:
        try:
            cliente.query("CALL BQ.ABORT_SESSION();", job_config=na_sessao).result()
        except Exception as erro:  # a sessão expira sozinha (24 h); não esconder o erro principal
            log("WARNING", f"não encerrou a sessão do BigQuery: {erro}")


def main() -> int:
    log("INFO", "início", tabelas=TABELAS, dry_run=DRY_RUN, exigir_silver_do_dia=EXIGIR_SILVER_DO_DIA)
    if set(TABELAS) != set(TABELAS_PRODUCAO):
        log("WARNING", "TABELAS diferente da lista de produção",
            fora_da_execucao=sorted(set(TABELAS_PRODUCAO) - set(TABELAS)),
            fora_da_producao=sorted(set(TABELAS) - set(TABELAS_PRODUCAO)))
    cliente = bigquery.Client(project=PROJETO, location=LOCAL)
    try:
        if EXIGIR_SILVER_DO_DIA:
            esperar_silver(cliente)
        resumos = atualizar(cliente, TABELAS)
    except Exception as erro:
        log("ERROR", f"gold-agenciamento falhou: {erro}")
        return 1
    log("INFO", "fim", resumos=resumos, dry_run=DRY_RUN)
    return 0


if __name__ == "__main__":
    sys.exit(main())

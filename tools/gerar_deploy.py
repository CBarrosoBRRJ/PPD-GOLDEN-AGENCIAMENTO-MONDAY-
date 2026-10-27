"""Gera os comandos de uma tabela gold a partir do SELECT (sql/) e do esquema (sql/esquemas/).

Uso: python tools/gerar_deploy.py gld_agenciamento_2026_sla_movimentos
Saída:
  deploy/criar_<tabela>.sql     CREATE OR REPLACE TABLE ... (colunas com descrição) ... AS <SELECT> — tabela nova
                                ou mudança de esquema (apaga a permissão da tabela: dar de novo).
  deploy/descrever_<tabela>.sql ALTER TABLE / ALTER COLUMN ... SET OPTIONS(description) — só atualiza as descrições
                                da tabela e das colunas, sem mexer em dados, esquema ou permissões (o job grava por
                                DELETE + INSERT e não toca em descrições).

O SELECT e o esquema são a única fonte; os arquivos de deploy são gerados e não devem ser editados à mão.
"""

import csv
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PROJETO_GCP = "gglobo-viu-dados-hdg-prd"
DATASET = "gold_monday"

TABELAS = {
    "gld_agenciamento_2026_sla_movimentos": {
        "descricao": (
            "SLA do board Backlog 2026 | Agenciamento: uma linha por passagem de um projeto por um status "
            "(projeto_id + passo), com fase (equipe, cliente, standby, fechamento), tempo corrido e útil, "
            "tempo em aberto, alerta e marcações do fluxo. Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_2026_sla_movimentos.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["projeto_id", "status_atual"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "sla-movimentos",
        },
    },
    "gld_agenciamento_entrada_diaria": {
        "descricao": (
            "Entrada e saída diárias do Agenciamento: cards criados (data real em quantidade, estimada em "
            "quantidade_estimada) e entregues ao cliente (quantidade_saida: 1ª ida a Aguardando Feedback) nos boards "
            "2024, 2025 e 2026 por dia, grupo de input, tipo de input e família, de 2024-10-01 até ontem, só "
            "combinações com entrada ou saída; e a situação hoje dos cards que entraram no dia (safra: "
            "entregue_no_mes, entregue_depois, nao_seguiu, em_andamento — foto do dia). Para tendência, previsão de "
            "demanda e relatório por safra; recortes na leitura. "
            "Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_entrada_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["data", "grupo_input"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2024-2026",
            "origem": "monday",
            "tipo": "entrada-diaria",
        },
    },
    "gld_agenciamento_fluxo_mensal": {
        "descricao": (
            "Extrato por safra do Agenciamento (boards 2024, 2025 e 2026): para os cards que entraram em cada mês "
            "(mes_entrada, de 2024-10 em diante), o que aconteceu até hoje e em que mês — entregue (1ª entrega ao "
            "cliente), nao_seguiu (Declinado, Standby ou Encerrado sem entrega; mês pelo log do board 2026, NULL em "
            "2024/2025) ou em_andamento — por grupo de input, tipo de input e família. Cada card conta uma vez. Mesmas "
            "regras de card da gld_agenciamento_entrada_diaria. Foto do dia: recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_fluxo_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["mes_entrada", "evento"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2024-2026",
            "origem": "monday",
            "tipo": "fluxo-mensal",
        },
    },
    "gld_agenciamento_2026_talentos_ano": {
        "descricao": (
            "Divisão anual dos pedidos do board 2026 entre Exclusivos, Não exclusivos (inclui Squad de Talentos) e "
            "Sem talento, de 1º/jan até ontem, com a exclusividade na data do pedido (silver) e as regras de data da "
            "gld_agenciamento_entrada_diaria; o total é igual às entradas do ano da diária. Uma linha por categoria. "
            "Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_2026_talentos_ano.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["ano", "categoria"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "talentos-ano",
        },
    },
    "gld_agenciamento_2026_talentos_ranking": {
        "descricao": (
            "Ranking de talentos do board 2026 no ano (1º/jan até ontem), por recorte (todos, exclusivo, "
            "nao-exclusivo): os 10 com mais pedidos e os que passaram pelos 10 do acumulado no fim de algum mês "
            "(corrida do ano), com os pedidos de cada um mês a mês. Mesma população da "
            "gld_agenciamento_2026_talentos_ano; sem Squad de Talentos e sem pedidos sem talento. Uma linha por "
            "recorte × talento × mês com pedido. Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_2026_talentos_ranking.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["grupo", "pos"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "talentos-ranking",
        },
    },
    "gld_agenciamento_2026_saidas_status": {
        "descricao": (
            "Saídas sem entrega do board 2026 por mês do evento e status final (Declinado*, Standby, Encerrado), para "
            "os cards que entraram no ano (1º/jan até ontem): a composição do evento nao_seguiu da "
            "gld_agenciamento_fluxo_mensal, que não guarda o status. Mesmas regras do fluxo; sem data no log, mês de "
            "entrada. Uma linha por mês × status. Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_2026_saidas_status.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["mes", "status"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "saidas-status",
        },
    },
    "gld_agenciamento_2026_previsao_exclusividade_diaria": {
        "descricao": (
            "Pedidos do board 2026 por dia de entrada e tipo de input (Inbound, Mercado), divididos em exclusivos, "
            "não exclusivos e sem talento (exclusividade na data do pedido), todo dia de 1º/jan até ontem, com zero "
            "quando não há pedido; dia_util marca seg–sex fora dos feriados. O total de cada dia e tipo é igual às "
            "entradas da gld_agenciamento_entrada_diaria. Base das séries da previsão de demanda (a mensal é view "
            "sobre esta). Uma linha por dia × tipo. Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["data", "tipo"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "previsao-exclusividade-diaria",
        },
    },
    "gld_agenciamento_2026_previsao_lotes": {
        "descricao": (
            "Pedidos do board 2026 por dia de entrada e recorte da previsão (inbound, mercado, mercado_exclusivos, "
            "mercado_nao_exclusivos), separados em pedidos em lote (3 ou mais do recorte com a mesma marca no mesmo "
            "dia) e avulsos, de 1º/jan até ontem; só dias com pedido. Pedidos de cada dia e recorte iguais à "
            "gld_agenciamento_2026_previsao_exclusividade_diaria. Diagnóstico do mês em andamento da previsão. Uma "
            "linha por dia × recorte. Recriada a cada execução. "
            "Regras: docs/tabelas/gld_agenciamento_2026_previsao_lotes.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "cluster": ["data", "recorte"],
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "previsao-lotes",
        },
    },
}


# views: soma ou recorte de uma tabela gold, sem cálculo próprio (sempre iguais à base; não entram no job). Criar
# depois da base, na ordem do cadastro (uma view pode ler outra)
VIEWS = {
    "gld_agenciamento_2026_previsao_exclusividade_mensal": {
        "descricao": (
            "Pedidos do board 2026 por mês de entrada e tipo de input (Inbound, Mercado), divididos em exclusivos"
            ", não exclusivos e sem talento (view, sem cálculo próprio: soma por mês da gld_agenciamento_2026_pre"
            "visao_exclusividade_diaria); completo separa os meses fechados do mês de ontem, ainda parcial. Uma l"
            "inha por mês × tipo. Sempre igual à base"
            ". Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "previsao-exclusividade-mensal",
        },
    },
    "gld_agenciamento_2026_previsao_exclusividade_mensal_inbound": {
        "descricao": (
            "Só Inbound da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio): pedidos "
            "do board 2026 por mês de entrada, divididos em exclusivos, não exclusivos e sem talento, de janeiro até "
            "ontem; completo separa os meses fechados do mês corrente. Uma linha por mês. Sempre igual à base. "
            "Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md "
            "(PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "previsao-exclusividade-mensal-inbound",
        },
    },
    "gld_agenciamento_2026_previsao_exclusividade_mensal_mercado": {
        "descricao": (
            "Só Mercado da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio): pedidos "
            "do board 2026 por mês de entrada, divididos em exclusivos, não exclusivos e sem talento, de janeiro até "
            "ontem; completo separa os meses fechados do mês corrente. Uma linha por mês. Sempre igual à base. "
            "Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md "
            "(PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "previsao-exclusividade-mensal-mercado",
        },
    },
    "gld_agenciamento_2026_sla_entregas": {
        "descricao": (
            "Um orçamento entregue por linha (view sobre a gld_agenciamento_2026_sla_movimentos): mês da 1ª entre"
            "ga e o tempo até ela, em horas de trabalho da equipe sem almoço (total, fila, elaboração, revisão), "
            "horas de calendário e dias úteis inteiros e com fração. Base do SLA de entrega do site. Sempre igual"
            " à base"
            ". Regras: docs/tabelas/gld_agenciamento_2026_sla_entregas.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "sla-entregas",
        },
    },
    "gld_agenciamento_2026_sla_entregas_status": {
        "descricao": (
            "Horas de trabalho sem almoço de cada orçamento entregue em cada status da equipe antes da 1ª entrega"
            " (view sobre a gld_agenciamento_2026_sla_movimentos); por orçamento, soma o h_trabalho da gld_agenci"
            "amento_2026_sla_entregas. Sempre igual à base"
            ". Regras: docs/tabelas/gld_agenciamento_2026_sla_entregas.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2026",
            "origem": "monday",
            "tipo": "sla-entregas-status",
        },
    },
    "gld_agenciamento_fila_mensal": {
        "descricao": (
            "Extrato de fila por mês e mês de entrada (view sobre a gld_agenciamento_fluxo_mensal): represados e "
            "novos no início, entregues e saídas sem entrega no mês, e o que segue aberto no fim; só pedidos do p"
            "róprio ano, mais as entregas do mês de safras de anos anteriores. Sempre igual à base"
            ". Regras: docs/tabelas/gld_agenciamento_fila_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2024-2026",
            "origem": "monday",
            "tipo": "fila-mensal",
        },
    },
    "gld_agenciamento_atendimento_mensal": {
        "descricao": (
            "O mês do Atendimento (view sobre a gld_agenciamento_entrada_diaria, a gld_agenciamento_fluxo_mensal "
            "e a gld_agenciamento_2026_saidas_status): entradas, entregues e saídas sem entrega dos pedidos do an"
            "o, fila que veio e que ficou, para atender, saídas externas e a demanda que dependia da equipe. Semp"
            "re igual às bases"
            ". Regras: docs/tabelas/gld_agenciamento_atendimento_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2024-2026",
            "origem": "monday",
            "tipo": "atendimento-mensal",
        },
    },
    "gld_agenciamento_previsao_mensal": {
        "descricao": (
            "Pedidos por mês de entrada e tipo de input (Inbound, Mercado) desde 2024-10 (view sobre a gld_agenci"
            "amento_entrada_diaria, soma por mês); completo separa os meses fechados do mês de ontem. Séries long"
            "as da previsão de demanda. Sempre igual à base"
            ". Regras: docs/tabelas/gld_agenciamento_previsao_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)"
        ),
        "labels": {
            "projeto": "ppd-golden-agenciamento-monday",
            "camada": "gold",
            "board": "agenciamento-2024-2026",
            "origem": "monday",
            "tipo": "previsao-mensal",
        },
    },
}


def texto(valor: str) -> str:
    """Literal de string do BigQuery."""
    return '"' + valor.replace("\\", "\\\\").replace('"', '\\"') + '"'


def gerar(tabela: str) -> Path:
    conf = TABELAS[tabela]
    select = (RAIZ / "sql" / f"{tabela}.sql").read_text(encoding="utf-8").rstrip().rstrip(";")
    with (RAIZ / "sql" / "esquemas" / f"{tabela}.csv").open(encoding="utf-8", newline="") as f:
        colunas = list(csv.DictReader(f))

    linhas_colunas = ",\n".join(
        f"  {c['coluna']} {c['tipo']} OPTIONS(description={texto(c['descricao'])})" for c in colunas
    )
    labels = ", ".join(f"({texto(k)}, {texto(v)})" for k, v in conf["labels"].items())

    ddl = (
        f"-- GERADO por tools/gerar_deploy.py a partir de sql/{tabela}.sql e sql/esquemas/{tabela}.csv.\n"
        "-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.\n"
        f"-- Executar no BigQuery com a conta corporativa, no projeto {PROJETO_GCP} (região US).\n"
        "-- Recria a tabela inteira (CREATE OR REPLACE): seguro repetir; não apaga nada fora desta tabela.\n\n"
        f"CREATE OR REPLACE TABLE `{PROJETO_GCP}.{DATASET}.{tabela}`\n"
        f"(\n{linhas_colunas}\n)\n"
        f"CLUSTER BY {', '.join(conf['cluster'])}\n"
        f"OPTIONS(\n  description={texto(conf['descricao'])},\n  labels=[{labels}]\n)\n"
        f"AS\n{select}\n;\n"
    )
    destino = RAIZ / "deploy" / f"criar_{tabela}.sql"
    destino.write_text(ddl, encoding="utf-8")
    return destino


def gerar_descricoes(tabela: str) -> Path:
    conf = TABELAS[tabela]
    with (RAIZ / "sql" / "esquemas" / f"{tabela}.csv").open(encoding="utf-8", newline="") as f:
        colunas = list(csv.DictReader(f))

    nome = f"`{PROJETO_GCP}.{DATASET}.{tabela}`"
    # duas instruções, não uma por coluna: o BigQuery limita a 5 atualizações de metadado por tabela a cada 10 s
    # (em 23/10/2026 um script com 17 instruções parou na 8ª com "too many table update operations")
    clausulas = ",\n".join(
        f"  ALTER COLUMN {c['coluna']} SET OPTIONS(description={texto(c['descricao'])})" for c in colunas
    )
    ddl = (
        f"-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/{tabela}.csv.\n"
        "-- Não editar à mão: altere o esquema e gere de novo.\n"
        f"-- Executar no BigQuery com a conta corporativa, no projeto {PROJETO_GCP} (região US).\n"
        "-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro\n"
        "-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).\n"
        "-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.\n\n"
        f"ALTER TABLE {nome} SET OPTIONS(description={texto(conf['descricao'])});\n\n"
        f"ALTER TABLE {nome}\n{clausulas};\n"
    )
    destino = RAIZ / "deploy" / f"descrever_{tabela}.sql"
    destino.write_text(ddl, encoding="utf-8")
    return destino


def gerar_view(view: str) -> Path:
    conf = VIEWS[view]
    select = (RAIZ / "sql" / f"{view}.sql").read_text(encoding="utf-8").rstrip().rstrip(";")
    with (RAIZ / "sql" / "esquemas" / f"{view}.csv").open(encoding="utf-8", newline="") as f:
        colunas = list(csv.DictReader(f))

    # numa view, a lista de colunas leva só nome e descrição (o tipo vem do SELECT)
    linhas_colunas = ",\n".join(f"  {c['coluna']} OPTIONS(description={texto(c['descricao'])})" for c in colunas)
    labels = ", ".join(f"({texto(k)}, {texto(v)})" for k, v in conf["labels"].items())

    ddl = (
        f"-- GERADO por tools/gerar_deploy.py a partir de sql/{view}.sql e sql/esquemas/{view}.csv.\n"
        "-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.\n"
        f"-- Executar no BigQuery com a conta corporativa, no projeto {PROJETO_GCP} (região US), depois de criar a\n"
        "-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.\n\n"
        f"CREATE OR REPLACE VIEW `{PROJETO_GCP}.{DATASET}.{view}`\n"
        f"(\n{linhas_colunas}\n)\n"
        f"OPTIONS(\n  description={texto(conf['descricao'])},\n  labels=[{labels}]\n)\n"
        f"AS\n{select}\n;\n"
    )
    destino = RAIZ / "deploy" / f"criar_{view}.sql"
    destino.write_text(ddl, encoding="utf-8")
    return destino


if __name__ == "__main__":
    nomes = sys.argv[1:] or list(TABELAS) + list(VIEWS)
    for nome in nomes:
        if nome in VIEWS:
            print(gerar_view(nome).relative_to(RAIZ))
            continue
        print(gerar(nome).relative_to(RAIZ))
        print(gerar_descricoes(nome).relative_to(RAIZ))

"""Gera o comando de criação de uma tabela gold a partir do SELECT (sql/) e do esquema (sql/esquemas/).

Uso: python tools/gerar_deploy.py gld_agenciamento_2026_sla_movimentos
Saída: deploy/criar_<tabela>.sql (CREATE OR REPLACE TABLE ... (colunas com descrição) ... AS <SELECT>).

O SELECT e o esquema são a única fonte; o arquivo de deploy é gerado e não deve ser editado à mão.
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
            "combinações com entrada ou saída. Para tendência e previsão de demanda; recortes na leitura. "
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


if __name__ == "__main__":
    nomes = sys.argv[1:] or list(TABELAS)
    for nome in nomes:
        print(gerar(nome).relative_to(RAIZ))

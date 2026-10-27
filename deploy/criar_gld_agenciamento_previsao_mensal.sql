-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_previsao_mensal.sql e sql/esquemas/gld_agenciamento_previsao_mensal.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_previsao_mensal`
(
  mes OPTIONS(description="1º dia do mês de entrada, de 2024-10 até o mês de ontem. Com tipo, forma a chave"),
  tipo OPTIONS(description="Tipo de input: Inbound ou Mercado"),
  pedidos OPTIONS(description="quantidade + quantidade_estimada da gld_agenciamento_entrada_diaria no mês"),
  estimados OPTIONS(description="Dos pedidos, quantos com data estimada"),
  completo OPTIONS(description="TRUE = mês fechado; FALSE = mês de ontem, parcial"),
  dados_ate OPTIONS(description="Ontem: último dia da carga (véspera do _processado_em, em São Paulo)"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_entrada_diaria que a view lê")
)
OPTIONS(
  description="Pedidos por mês de entrada e tipo de input (Inbound, Mercado) desde 2024-10 (view sobre a gld_agenciamento_entrada_diaria, soma por mês); completo separa os meses fechados do mês de ontem. Séries longas da previsão de demanda. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_previsao_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2024-2026"), ("origem", "monday"), ("tipo", "previsao-mensal")]
)
AS
-- gold_monday.gld_agenciamento_previsao_mensal (VIEW) — pedidos por mês de entrada e tipo de input (Inbound, Mercado),
-- de 2024-10 até o mês de ontem: as séries longas da previsão de demanda (S1 Inbound, S2 Mercado). Ficha:
-- docs/tabelas/gld_agenciamento_previsao_mensal.md. Base: gld_agenciamento_entrada_diaria (soma por mês, sem regra
-- própria). Reproduz SQL_SERIE de ml/dados.py do site. View: sempre igual à base, não entra no job.
-- completo = o mês terminou até ontem (véspera da carga, em São Paulo); o mês de ontem fica FALSE, ainda parcial.
WITH e AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia, MAX(_processado_em) AS carga
  FROM e
)

SELECT
  DATE_TRUNC(e.data, MONTH) AS mes,
  e.tipo_de_input AS tipo,
  SUM(e.quantidade + e.quantidade_estimada) AS pedidos,
  SUM(e.quantidade_estimada) AS estimados,
  LAST_DAY(MIN(e.data)) <= ANY_VALUE(o.dia) AS completo,
  ANY_VALUE(o.dia) AS dados_ate,
  ANY_VALUE(o.carga) AS _processado_em
FROM e, ontem o
WHERE e.tipo_de_input IN ('Inbound', 'Mercado') AND e.data <= o.dia
GROUP BY mes, tipo
;

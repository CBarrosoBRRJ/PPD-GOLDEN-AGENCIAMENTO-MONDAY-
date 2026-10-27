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

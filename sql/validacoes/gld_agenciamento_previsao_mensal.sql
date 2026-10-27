-- Validação de gold_monday.gld_agenciamento_previsao_mensal (só leitura; view sobre a gld_agenciamento_entrada_diaria).
-- Rodar depois de criar a view e quando a base mudar de regra. Toda linha deve sair com ok = TRUE. É view: não entra no job.
-- Confere os meses de 2024-10 até o mês de ontem nos dois tipos (sem buraco), o total contra a diária, os estimados e,
-- no ano de ontem, cada mês × tipo contra a gld_agenciamento_2026_previsao_exclusividade_diaria (mesma população).

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_previsao_mensal`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

x AS (
  SELECT DATE_TRUNC(data, MONTH) AS mes, tipo, SUM(total) AS n
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
  GROUP BY mes, tipo
),

ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia FROM d
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, tipo)) AS chaves,
    COUNTIF(tipo NOT IN ('Inbound', 'Mercado')) AS tipo_invalido,
    COUNTIF(pedidos < 0 OR estimados < 0 OR estimados > pedidos) AS contagem_invalida,
    COUNTIF(completo != (LAST_DAY(mes) <= o.dia) OR dados_ate != o.dia) AS completo_errado,
    SUM(pedidos) AS pedidos
  FROM t, ontem o
),

diaria AS (
  SELECT SUM(d.quantidade + d.quantidade_estimada) AS pedidos
  FROM d, ontem o
  WHERE d.tipo_de_input IN ('Inbound', 'Mercado') AND d.data <= o.dia
),

ano AS (
  SELECT COUNT(*) AS diferentes
  FROM (SELECT t.mes, t.tipo, t.pedidos FROM t, ontem o WHERE EXTRACT(YEAR FROM t.mes) = EXTRACT(YEAR FROM o.dia)) a
  FULL JOIN x b USING (mes, tipo)
  WHERE a.pedidos IS DISTINCT FROM b.n
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, diaria e, ano n, ontem o, UNNEST([
  STRUCT(
    'chave mês × tipo única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses de 2024-10 até o mês de ontem, nos dois tipos', CAST(r.linhas AS STRING),
    CAST(2 * (DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2024-10-01', MONTH) + 1) AS STRING),
    r.linhas = 2 * (DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2024-10-01', MONTH) + 1)),
  ('tipo fora de Inbound, Mercado', CAST(r.tipo_invalido AS STRING), '0', r.tipo_invalido = 0),
  ('contagens negativas ou estimados acima dos pedidos', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('completo ou dados_ate errados (só o mês de ontem fica parcial)', CAST(r.completo_errado AS STRING), '0',
    r.completo_errado = 0),
  ('total = entradas Inbound + Mercado da gld_agenciamento_entrada_diaria até ontem', CAST(r.pedidos AS STRING),
    CAST(e.pedidos AS STRING), r.pedidos = e.pedidos),
  ('ano de ontem: mês × tipo ≠ gld_agenciamento_2026_previsao_exclusividade_diaria', CAST(n.diferentes AS STRING), '0',
    n.diferentes = 0),
  ('mês de ontem (Inbound | Mercado)',
    (SELECT STRING_AGG(CAST(pedidos AS STRING), ' | ' ORDER BY tipo) FROM t WHERE mes = DATE_TRUNC(o.dia, MONTH)),
    'informativo', TRUE)
])

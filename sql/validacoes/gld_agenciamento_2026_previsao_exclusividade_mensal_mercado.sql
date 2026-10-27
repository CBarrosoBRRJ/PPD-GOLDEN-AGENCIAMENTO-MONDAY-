-- Validação de gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_mercado (só leitura). Rodar depois de criar a view.
-- A view só filtra a gld_agenciamento_2026_previsao_exclusividade: as linhas dela são as de tipo = 'Mercado' da base, coluna a coluna.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_mercado`
),

b AS (
  SELECT * EXCEPT (tipo) FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal` WHERE tipo = 'Mercado'
),

dif AS (
  SELECT COUNT(*) AS n FROM (
    (SELECT * EXCEPT (_processado_em) FROM t EXCEPT DISTINCT SELECT * EXCEPT (_processado_em) FROM b)
    UNION ALL
    (SELECT * EXCEPT (_processado_em) FROM b EXCEPT DISTINCT SELECT * EXCEPT (_processado_em) FROM t))
)

SELECT verificacao, resultado, esperado, ok
FROM dif, UNNEST([
  STRUCT(
    'linhas = base com tipo Mercado' AS verificacao,
    FORMAT('%d (base %d)', (SELECT COUNT(*) FROM t), (SELECT COUNT(*) FROM b)) AS resultado,
    'iguais' AS esperado,
    (SELECT COUNT(*) FROM t) = (SELECT COUNT(*) FROM b) AS ok),
  ('linhas diferentes da base', CAST(dif.n AS STRING), '0', dif.n = 0),
  ('total do ano (Mercado)', CAST((SELECT SUM(total) FROM t) AS STRING), 'informativo', TRUE)
])

-- Validação de gold_monday.gld_agenciamento_2026_previsao_lotes (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job.
-- Confere os pedidos de cada dia e recorte contra a gld_agenciamento_2026_previsao_exclusividade_diaria (mesma população
-- e regras): inbound = total Inbound; mercado = total Mercado; mercado_exclusivos e mercado_nao_exclusivos = as partes.
-- No job, a exclusividade diária vem antes em TABELAS e a conferência lê o cálculo dela da mesma execução.
-- Começo de ano: tabela vazia é aceita (0 = 0 nas conferências).
-- Referência de 26/10/2026 (informativo): out/2026 até o dia 25, Mercado 304 = 170 em lote + 134 avulsos.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_lotes`
),

e AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

-- os quatro recortes da exclusividade diária, só nos dias com pedido (a lotes não grava zero)
base AS (
  SELECT data, recorte, n
  FROM e,
    UNNEST([
      STRUCT(IF(tipo = 'Inbound', 'inbound', 'mercado') AS recorte, total AS n),
      STRUCT(IF(tipo = 'Mercado', 'mercado_exclusivos', NULL), IF(tipo = 'Mercado', exclusivos, 0)),
      STRUCT(IF(tipo = 'Mercado', 'mercado_nao_exclusivos', NULL), IF(tipo = 'Mercado', nao_exclusivos, 0))])
  WHERE recorte IS NOT NULL AND n > 0
),

comparacao AS (
  SELECT COUNT(*) AS diferentes
  FROM (SELECT data, recorte, pedidos FROM t) x
  FULL JOIN base b USING (data, recorte)
  WHERE x.pedidos IS DISTINCT FROM b.n
),

mercado AS (
  SELECT data, SUM(IF(recorte = 'mercado', pedidos, 0)) AS todos,
    SUM(IF(recorte IN ('mercado_exclusivos', 'mercado_nao_exclusivos'), pedidos, 0)) AS partes
  FROM t GROUP BY data
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', data, recorte)) AS chaves,
    COUNTIF(recorte NOT IN ('inbound', 'mercado', 'mercado_exclusivos', 'mercado_nao_exclusivos')) AS recorte_invalido,
    COUNTIF(pedidos <= 0 OR em_lote < 0 OR avulsos < 0 OR lotes < 0) AS contagem_invalida,
    COUNTIF(em_lote + avulsos != pedidos) AS nao_somam,
    COUNTIF(em_lote < 3 * lotes OR (lotes = 0) != (em_lote = 0)) AS lote_incoerente,
    COUNTIF(data NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia) AS data_fora
  FROM t, ontem o
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, comparacao c, UNNEST([
  STRUCT(
    'chave data × recorte única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('recorte fora de inbound, mercado, mercado_exclusivos, mercado_nao_exclusivos', CAST(r.recorte_invalido AS STRING),
    '0', r.recorte_invalido = 0),
  ('contagens negativas ou dia sem pedido', CAST(r.contagem_invalida AS STRING), '0', r.contagem_invalida = 0),
  ('em_lote + avulsos ≠ pedidos', CAST(r.nao_somam AS STRING), '0', r.nao_somam = 0),
  ('lotes incoerentes (cada lote tem 3 ou mais pedidos)', CAST(r.lote_incoerente AS STRING), '0', r.lote_incoerente = 0),
  ('data fora do ano de ontem', CAST(r.data_fora AS STRING), '0', r.data_fora = 0),
  ('dia × recorte com pedidos diferentes da gld_agenciamento_2026_previsao_exclusividade_diaria',
    CAST(c.diferentes AS STRING), '0', c.diferentes = 0),
  ('dias com mercado_exclusivos + mercado_nao_exclusivos acima do mercado',
    (SELECT CAST(COUNTIF(partes > todos) AS STRING) FROM mercado), '0', (SELECT COUNTIF(partes > todos) = 0 FROM mercado)),
  ('mês de ontem até ontem: pedidos = em lote + avulsos, por recorte',
    (SELECT STRING_AGG(FORMAT('%s: %d = %d + %d', recorte, p, l, a), ' | ' ORDER BY recorte)
     FROM (SELECT recorte, SUM(pedidos) p, SUM(em_lote) l, SUM(avulsos) a FROM t, ontem o
           WHERE data >= DATE_TRUNC(o.dia, MONTH) GROUP BY recorte)), 'informativo', TRUE)
])

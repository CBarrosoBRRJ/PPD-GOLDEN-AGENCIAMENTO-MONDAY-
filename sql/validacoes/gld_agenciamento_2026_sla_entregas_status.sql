-- Validação de gold_monday.gld_agenciamento_2026_sla_entregas_status (só leitura; view sobre a
-- gld_agenciamento_2026_sla_movimentos). Rodar depois de criar a view e a gld_agenciamento_2026_sla_entregas.
-- Toda linha deve sair com ok = TRUE. É view: não entra no job.
-- Confere que só há orçamentos entregues e que, por orçamento, a soma das horas por status = h_trabalho da
-- gld_agenciamento_2026_sla_entregas (mesma regra E1/E2).
-- Aviso: horas nulas = a coluna sla_sem_almoco_horas (R24) ainda não foi calculada pelo job.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas_status`
),

e AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas`
),

soma AS (
  SELECT projeto_id, SUM(IFNULL(h, 0)) AS h FROM t GROUP BY projeto_id
),

comparacao AS (
  SELECT
    COUNTIF(e.projeto_id IS NULL) AS fora_das_entregas,
    COUNTIF(ABS(IFNULL(s.h, 0) - IFNULL(e.h_trabalho, 0)) > 1e-6) AS soma_diferente
  FROM soma s FULL JOIN e USING (projeto_id)
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', projeto_id, status)) AS chaves,
    COUNTIF(status IS NULL OR h < 0) AS invalidas,
    COUNTIF(h IS NULL) AS h_nulo,
    COUNT(DISTINCT projeto_id) AS projetos,
    COUNTIF(STARTS_WITH(LOWER(status), 'em elaboração - retorno marca')) AS retorno_marca
  FROM t
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, comparacao c, UNNEST([
  STRUCT(
    'chave projeto_id × status única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('status vazio ou horas negativas', CAST(r.invalidas AS STRING), '0', r.invalidas = 0),
  ('Em elaboração - Retorno Marca presente (espera da marca, fora do trabalho)', CAST(r.retorno_marca AS STRING), '0',
    r.retorno_marca = 0),
  ('orçamentos fora da gld_agenciamento_2026_sla_entregas', CAST(c.fora_das_entregas AS STRING), '0',
    c.fora_das_entregas = 0),
  ('orçamentos com soma por status ≠ h_trabalho da gld_agenciamento_2026_sla_entregas', CAST(c.soma_diferente AS STRING),
    '0', c.soma_diferente = 0),
  ('horas sem almoço ainda não calculadas (R24 vazia na SLA)', CAST(r.h_nulo AS STRING), 'aviso', TRUE),
  ('orçamentos com horas por status', CAST(r.projetos AS STRING), 'informativo', TRUE)
])

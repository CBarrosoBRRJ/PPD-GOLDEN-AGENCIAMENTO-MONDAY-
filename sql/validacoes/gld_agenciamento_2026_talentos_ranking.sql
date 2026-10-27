-- Validação de gold_monday.gld_agenciamento_2026_talentos_ranking (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job.
-- Confere a concentração do top 10 contra a gld_agenciamento_2026_talentos_ano (mesma população): os pedidos dos 10
-- primeiros nunca passam dos pedidos da categoria. No job, a talentos_ano vem antes em TABELAS e a conferência lê o
-- cálculo dela da mesma execução.
-- Referência de 26/10/2026 (informativo): 1º lugar em todos, exclusivo e nao-exclusivo; participantes da corrida.
-- Virada do ano: no começo de janeiro um recorte pode ter menos de 10 talentos (ou nenhum). O top exigido é o menor
-- entre 10 e os talentos do recorte; recorte com menos de 10 vira aviso, e recorte ausente só é aceito em janeiro.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ranking`
),

a AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
),

por_talento AS (
  SELECT grupo, talento, COUNT(DISTINCT n) AS ns, ANY_VALUE(n) AS n, COUNT(DISTINCT pos) AS poss, ANY_VALUE(pos) AS pos,
    SUM(n_mes) AS soma_meses, MAX(mes) AS ultimo_mes, ANY_VALUE(ultimo_pedido) AS ultimo_pedido,
    ANY_VALUE(talentos_grupo) AS talentos_grupo
  FROM t
  GROUP BY grupo, talento
),

por_grupo AS (
  SELECT grupo,
    LEAST(10, MAX(talentos_grupo)) AS top_esperado,
    COUNTIF(pos <= 10) AS no_top,
    COUNT(DISTINCT IF(pos <= 10, pos, NULL)) AS lugares,
    SUM(IF(pos <= 10, n, 0)) AS pedidos_top,
    COUNTIF(pos > 10) AS so_na_corrida,
    ARRAY_AGG(IF(pos = 1, FORMAT('%s (%d)', talento, n), NULL) IGNORE NULLS)[SAFE_OFFSET(0)] AS primeiro
  FROM por_talento
  GROUP BY grupo
),

base AS (
  SELECT SUM(IF(categoria = 'Exclusivos', n, 0)) AS ex, SUM(IF(categoria = 'Não exclusivos', n, 0)) AS nex FROM a
),

conc AS (
  SELECT g.grupo, g.pedidos_top,
    CASE g.grupo WHEN 'exclusivo' THEN b.ex WHEN 'nao-exclusivo' THEN b.nex ELSE b.ex + b.nex END AS pedidos_recorte
  FROM por_grupo g CROSS JOIN base b
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t|%t', grupo, LOWER(talento), mes)) AS chaves,
    COUNTIF(grupo NOT IN ('todos', 'exclusivo', 'nao-exclusivo')) AS grupo_invalido,
    COUNTIF(n IS NULL OR n_mes IS NULL OR n <= 0 OR n_mes <= 0 OR n_mes > n) AS contagem_invalida,
    COUNTIF(mes NOT BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR)
                        AND DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY)
            OR mes != DATE_TRUNC(mes, MONTH)) AS mes_fora,
    COUNTIF(LOWER(TRIM(talento)) IN ('', 'squad de talentos') OR talento IS NULL) AS talento_invalido,
    COUNT(DISTINCT IF(talentos_grupo < 10, grupo, NULL)) AS grupo_pequeno
  FROM t
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, ontem o, UNNEST([
  STRUCT(
    'chave grupo × talento × mês única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('grupo fora de todos, exclusivo, nao-exclusivo', CAST(r.grupo_invalido AS STRING), '0', r.grupo_invalido = 0),
  ('recortes presentes (menos de 3 só em janeiro)', (SELECT CAST(COUNT(*) AS STRING) FROM por_grupo), '3',
    (SELECT COUNT(*) FROM por_grupo) = 3 OR EXTRACT(MONTH FROM o.dia) = 1),
  ('talento vazio, nulo ou Squad de Talentos', CAST(r.talento_invalido AS STRING), '0', r.talento_invalido = 0),
  ('contagens nulas, não positivas ou mês maior que o ano', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('mês fora do ano de ontem ou que não é 1º dia', CAST(r.mes_fora AS STRING), '0', r.mes_fora = 0),
  ('recortes com menos de 10 talentos no ano (começo de ano)', CAST(r.grupo_pequeno AS STRING), 'aviso', TRUE),
  ('talentos com n, pos ou último pedido incoerentes entre os meses, ou n ≠ soma dos meses',
    (SELECT CAST(COUNTIF(ns > 1 OR poss > 1 OR n != soma_meses OR ultimo_mes != DATE_TRUNC(ultimo_pedido, MONTH))
            AS STRING) FROM por_talento), '0',
    (SELECT COUNTIF(ns > 1 OR poss > 1 OR n != soma_meses OR ultimo_mes != DATE_TRUNC(ultimo_pedido, MONTH)) = 0
     FROM por_talento)),
  ('recortes sem top completo (lugares 1 a 10, ou 1 a N quando o recorte tem N < 10 talentos)',
    (SELECT CAST(COUNTIF(no_top != top_esperado OR lugares != top_esperado) AS STRING) FROM por_grupo), '0',
    (SELECT COUNTIF(no_top != top_esperado OR lugares != top_esperado) = 0 FROM por_grupo)),
  ('top 10 com mais pedidos que a categoria na gld_agenciamento_2026_talentos_ano (recortes)',
    (SELECT STRING_AGG(FORMAT('%s: %d de %d', grupo, pedidos_top, pedidos_recorte), ' | ' ORDER BY grupo) FROM conc),
    'top ≤ categoria', (SELECT COUNTIF(pedidos_top > pedidos_recorte) = 0 FROM conc)),
  ('1º lugar por recorte',
    (SELECT STRING_AGG(FORMAT('%s: %s', grupo, primeiro), ' | ' ORDER BY grupo) FROM por_grupo), 'informativo', TRUE),
  ('talentos só na corrida do acumulado (pos > 10), por recorte',
    (SELECT STRING_AGG(FORMAT('%s: %d', grupo, so_na_corrida), ' | ' ORDER BY grupo) FROM por_grupo), 'informativo',
    TRUE)
])

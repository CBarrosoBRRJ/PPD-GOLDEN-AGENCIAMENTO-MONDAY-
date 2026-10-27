-- Validação de gold_monday.gld_agenciamento_2026_saidas_status (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job.
-- Confere, mês a mês, contra o evento nao_seguiu da gld_agenciamento_fluxo_mensal na safra do ano (mesmas regras, sem
-- o status). No fluxo, o card sem data no log fica com mes_evento NULL; aqui ele vai ao mês de entrada (S1), então a
-- conferência usa COALESCE(mes_evento, mes_entrada). No job, o fluxo vem antes em TABELAS e a conferência lê o cálculo
-- dele da mesma execução.
-- Referência de 26/10/2026 (informativo): 974 saídas sem entrega na safra de 2026.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status`
),

f AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

por_mes AS (
  SELECT
    COALESCE(a.mes, b.mes) AS mes, IFNULL(a.n, 0) AS status, IFNULL(b.n, 0) AS fluxo
  FROM (SELECT mes, SUM(n) AS n FROM t GROUP BY mes) a
  FULL JOIN (
    SELECT COALESCE(f.mes_evento, f.mes_entrada) AS mes, SUM(f.quantidade) AS n
    FROM f, ontem o
    WHERE f.evento = 'nao_seguiu' AND EXTRACT(YEAR FROM f.mes_entrada) = EXTRACT(YEAR FROM o.dia)
    GROUP BY mes) b
  USING (mes)
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, status)) AS chaves,
    COUNTIF(status IS NULL OR NOT (STARTS_WITH(status, 'Declinado') OR status IN ('Standby', 'Encerrado')))
      AS status_invalido,
    COUNTIF(n IS NULL OR n <= 0 OR sem_data < 0 OR sem_data > n) AS contagem_invalida,
    COUNTIF(mes NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia OR mes != DATE_TRUNC(mes, MONTH)) AS mes_fora,
    SUM(n) AS saidas,
    SUM(sem_data) AS sem_data,
    STRING_AGG(DISTINCT status, ', ' ORDER BY status) AS status_vistos
  FROM t, ontem o
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, UNNEST([
  STRUCT(
    'chave mês × status única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('status fora de Declinado*, Standby, Encerrado', CAST(r.status_invalido AS STRING), '0', r.status_invalido = 0),
  ('contagens nulas, não positivas ou sem_data maior que n', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('mês fora do ano de ontem ou que não é 1º dia', CAST(r.mes_fora AS STRING), '0', r.mes_fora = 0),
  -- IFNULL: no começo de janeiro as duas podem estar vazias (0 = 0)
  ('total = nao_seguiu da safra do ano no fluxo mensal', CAST(IFNULL(r.saidas, 0) AS STRING),
    (SELECT CAST(IFNULL(SUM(fluxo), 0) AS STRING) FROM por_mes),
    IFNULL(r.saidas, 0) = (SELECT IFNULL(SUM(fluxo), 0) FROM por_mes)),
  ('meses com soma dos status ≠ nao_seguiu do fluxo (mês do evento; sem data = mês de entrada)',
    IFNULL((SELECT STRING_AGG(FORMAT('%s: %d ≠ %d', FORMAT_DATE('%Y-%m', mes), status, fluxo), ' | ' ORDER BY mes)
            FROM por_mes WHERE status != fluxo), '0'),
    '0', (SELECT COUNTIF(status != fluxo) = 0 FROM por_mes)),
  ('saídas sem entrega por mês', (SELECT STRING_AGG(FORMAT('%s: %d', FORMAT_DATE('%Y-%m', mes), status), ' | '
    ORDER BY mes) FROM por_mes), 'informativo', TRUE),
  ('sem data no log (contados no mês de entrada)', CAST(r.sem_data AS STRING), 'informativo', TRUE),
  ('status vistos', r.status_vistos, 'informativo', TRUE)
])

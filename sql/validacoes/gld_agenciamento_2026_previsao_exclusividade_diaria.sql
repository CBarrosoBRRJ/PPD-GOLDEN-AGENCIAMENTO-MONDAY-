-- Validação de gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job.
-- Confere o total de cada dia × tipo contra a gld_agenciamento_entrada_diaria (mesmas regras de data), as partes contra
-- a gld_agenciamento_2026_talentos_ano (mesma regra de exclusividade: Inbound + Mercado nunca passam do ano inteiro),
-- o calendário completo (PD1) e o dia útil (PD2: sábado e domingo nunca são úteis; os feriados de seg a sex vão ao
-- log, contados). No job, a diária e a talentos_ano vêm antes em TABELAS e a conferência lê o cálculo delas da mesma
-- execução.
-- Referência de 26/10/2026 (informativo): soma por mês = a antiga tabela mensal (Mercado set/2026 194/272/11 = 477).

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

a AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

comparacao AS (
  SELECT COALESCE(x.data, y.data) AS data, COALESCE(x.tipo, y.tipo) AS tipo, IFNULL(x.n, 0) AS tabela,
    IFNULL(y.n, 0) AS diaria
  FROM (SELECT data, tipo, total AS n FROM t) x
  FULL JOIN (
    SELECT d.data, d.tipo_de_input AS tipo, SUM(d.quantidade + d.quantidade_estimada) AS n
    FROM d, ontem o
    WHERE d.tipo_de_input IN ('Inbound', 'Mercado') AND d.data BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia
    GROUP BY d.data, tipo) y
  ON x.data = y.data AND x.tipo = y.tipo
),

ano AS (
  -- IFNULL: no começo de janeiro a talentos_ano pode estar vazia
  SELECT IFNULL(SUM(IF(categoria = 'Exclusivos', n, 0)), 0) AS ex,
    IFNULL(SUM(IF(categoria = 'Não exclusivos', n, 0)), 0) AS nex,
    IFNULL(SUM(IF(categoria = 'Sem talento', n, 0)), 0) AS sem
  FROM a
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', data, tipo)) AS chaves,
    2 * (DATE_DIFF(ANY_VALUE(o.dia), DATE_TRUNC(ANY_VALUE(o.dia), YEAR), DAY) + 1) AS esperadas,
    COUNTIF(tipo NOT IN ('Inbound', 'Mercado')) AS tipo_invalido,
    COUNTIF(exclusivos IS NULL OR nao_exclusivos IS NULL OR sem_talento IS NULL OR total IS NULL OR dia_util IS NULL
            OR exclusivos < 0 OR nao_exclusivos < 0 OR sem_talento < 0) AS contagem_invalida,
    COUNTIF(exclusivos + nao_exclusivos + sem_talento != total) AS partes_nao_somam,
    COUNTIF(data NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia) AS data_fora,
    COUNTIF(dia_util AND EXTRACT(DAYOFWEEK FROM data) IN (1, 7)) AS fim_de_semana_util,
    COUNTIF(NOT dia_util AND EXTRACT(DAYOFWEEK FROM data) BETWEEN 2 AND 6) / 2 AS feriados_seg_sex,
    COUNTIF(dia_util) / 2 AS dias_uteis,
    IFNULL(SUM(exclusivos), 0) AS ex, IFNULL(SUM(nao_exclusivos), 0) AS nex, IFNULL(SUM(sem_talento), 0) AS sem,
    SUM(IF(NOT dia_util, total, 0)) AS pedidos_fora_dia_util
  FROM t, ontem o
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, ano n, UNNEST([
  STRUCT(
    'chave dia × tipo única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('calendário completo: todo dia de 1º/jan até ontem, nos dois tipos (PD1)', CAST(r.linhas AS STRING),
    CAST(r.esperadas AS STRING), r.linhas = r.esperadas),
  ('tipo fora de Inbound, Mercado', CAST(r.tipo_invalido AS STRING), '0', r.tipo_invalido = 0),
  ('contagens nulas ou negativas', CAST(r.contagem_invalida AS STRING), '0', r.contagem_invalida = 0),
  ('linhas em que as partes não somam o total', CAST(r.partes_nao_somam AS STRING), '0', r.partes_nao_somam = 0),
  ('data fora do ano de ontem', CAST(r.data_fora AS STRING), '0', r.data_fora = 0),
  ('sábado ou domingo marcado como dia útil (PD2)', CAST(r.fim_de_semana_util AS STRING), '0', r.fim_de_semana_util = 0),
  ('dia × tipo com total diferente da gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)',
    IFNULL((SELECT STRING_AGG(FORMAT('%t %s: %d ≠ %d', data, tipo, tabela, diaria), ' | ' ORDER BY data, tipo LIMIT 10)
            FROM comparacao WHERE tabela != diaria), '0'),
    '0', (SELECT COUNTIF(tabela != diaria) = 0 FROM comparacao)),
  ('partes acima da talentos_ano (exclusivos | não exclusivos | sem talento)',
    FORMAT('%d de %d | %d de %d | %d de %d', r.ex, n.ex, r.nex, n.nex, r.sem, n.sem), 'cada uma ≤ o ano',
    r.ex <= n.ex AND r.nex <= n.nex AND r.sem <= n.sem),
  ('dias úteis no ano | feriados de seg a sex', FORMAT('%d | %d', CAST(r.dias_uteis AS INT64), CAST(r.feriados_seg_sex AS INT64)),
    'informativo', TRUE),
  ('pedidos em dia não útil (fim de semana ou feriado)', CAST(r.pedidos_fora_dia_util AS STRING), 'informativo', TRUE),
  ('Mercado por mês (exclusivos / não exclusivos / sem talento)',
    (SELECT STRING_AGG(FORMAT('%s: %d/%d/%d', FORMAT_DATE('%Y-%m', mes), e, ne, st), ' | ' ORDER BY mes)
     FROM (SELECT DATE_TRUNC(data, MONTH) AS mes, SUM(exclusivos) AS e, SUM(nao_exclusivos) AS ne, SUM(sem_talento) AS st
           FROM t WHERE tipo = 'Mercado' GROUP BY mes)), 'informativo', TRUE)
])

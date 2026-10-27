-- Validação de gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal (só leitura; view sobre a gld_agenciamento_2026_previsao_exclusividade_diaria).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job.
-- Confere o total de cada mês × tipo contra a gld_agenciamento_entrada_diaria (mesmas regras de data) e as partes contra
-- a gld_agenciamento_2026_talentos_ano (mesma regra de exclusividade): Inbound + Mercado nunca passam do ano inteiro.
-- É view: não entra no job; rodar depois de criá-la e quando a base mudar de regra. A soma por mês da base
-- fica conferida também pela validação da própria base, dia a dia.
-- Referência de 26/10/2026 (informativo): Mercado por mês, exclusivos / não exclusivos.
-- Começo de mês (e de ano): o mês de ontem pode não ter pedido de um tipo ainda (ex.: dia 1º num domingo). Os meses
-- fechados são exigidos nos dois tipos; o mês corrente sem linha vira aviso.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal`
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

-- total por mês × tipo nas duas tabelas
comparacao AS (
  SELECT COALESCE(x.mes, y.mes) AS mes, COALESCE(x.tipo, y.tipo) AS tipo, IFNULL(x.n, 0) AS tabela, IFNULL(y.n, 0) AS diaria
  FROM (SELECT mes, tipo, total AS n FROM t) x
  FULL JOIN (
    SELECT DATE_TRUNC(d.data, MONTH) AS mes, d.tipo_de_input AS tipo, SUM(d.quantidade + d.quantidade_estimada) AS n
    FROM d, ontem o
    WHERE d.tipo_de_input IN ('Inbound', 'Mercado') AND d.data BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia
    GROUP BY mes, tipo) y
  ON x.mes = y.mes AND x.tipo = y.tipo
),

ano AS (
  SELECT IFNULL(SUM(IF(categoria = 'Exclusivos', n, 0)), 0) AS ex,
    IFNULL(SUM(IF(categoria = 'Não exclusivos', n, 0)), 0) AS nex,
    IFNULL(SUM(IF(categoria = 'Sem talento', n, 0)), 0) AS sem
  FROM a
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, tipo)) AS chaves,
    COUNTIF(tipo NOT IN ('Inbound', 'Mercado')) AS tipo_invalido,
    COUNTIF(exclusivos < 0 OR nao_exclusivos < 0 OR sem_talento < 0 OR total < 0) AS contagem_invalida,
    COUNTIF(exclusivos + nao_exclusivos + sem_talento != total) AS partes_nao_somam,
    COUNTIF(mes NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia OR mes != DATE_TRUNC(mes, MONTH)) AS mes_fora,
    COUNTIF(completo != (LAST_DAY(mes) <= o.dia)) AS completo_errado,
    -- IFNULL: no começo de janeiro a tabela pode estar vazia
    IFNULL(SUM(exclusivos), 0) AS ex, IFNULL(SUM(nao_exclusivos), 0) AS nex, IFNULL(SUM(sem_talento), 0) AS sem,
    COUNTIF(mes < DATE_TRUNC(o.dia, MONTH)) AS fechadas,
    COUNTIF(mes = DATE_TRUNC(o.dia, MONTH)) AS correntes
  FROM t, ontem o
),

-- meses fechados do ano (janeiro até o mês anterior ao de ontem), nos dois tipos
esperado AS (
  SELECT 2 * DATE_DIFF(DATE_TRUNC(dia, MONTH), DATE_TRUNC(dia, YEAR), MONTH) AS fechadas FROM ontem
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, ano n, esperado e, UNNEST([
  STRUCT(
    'chave mês × tipo única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses fechados do ano nos dois tipos (sem buraco)', CAST(r.fechadas AS STRING),
    CAST(e.fechadas AS STRING), r.fechadas = e.fechadas),
  ('tipos sem linha no mês de ontem (começo de mês, ainda sem pedido)', CAST(2 - r.correntes AS STRING), 'aviso', TRUE),
  ('tipo fora de Inbound, Mercado', CAST(r.tipo_invalido AS STRING), '0', r.tipo_invalido = 0),
  ('contagens negativas', CAST(r.contagem_invalida AS STRING), '0', r.contagem_invalida = 0),
  ('linhas em que as partes não somam o total', CAST(r.partes_nao_somam AS STRING), '0', r.partes_nao_somam = 0),
  ('mês fora do ano de ontem ou que não é 1º dia', CAST(r.mes_fora AS STRING), '0', r.mes_fora = 0),
  ('completo diferente de "último dia do mês até ontem"', CAST(r.completo_errado AS STRING), '0', r.completo_errado = 0),
  ('mês × tipo com total diferente da diária (quantidade + quantidade_estimada)',
    IFNULL((SELECT STRING_AGG(FORMAT('%s %s: %d ≠ %d', FORMAT_DATE('%Y-%m', mes), tipo, tabela, diaria), ' | '
                              ORDER BY mes, tipo)
            FROM comparacao WHERE tabela != diaria), '0'),
    '0', (SELECT COUNTIF(tabela != diaria) = 0 FROM comparacao)),
  ('partes acima da talentos_ano (exclusivos | não exclusivos | sem talento)',
    FORMAT('%d de %d | %d de %d | %d de %d', r.ex, n.ex, r.nex, n.nex, r.sem, n.sem), 'cada uma ≤ o ano',
    r.ex <= n.ex AND r.nex <= n.nex AND r.sem <= n.sem),
  ('Mercado por mês (exclusivos / não exclusivos / sem talento)',
    (SELECT STRING_AGG(FORMAT('%s: %d/%d/%d', FORMAT_DATE('%Y-%m', mes), exclusivos, nao_exclusivos, sem_talento), ' | '
                       ORDER BY mes) FROM t WHERE tipo = 'Mercado'), 'informativo', TRUE),
  ('Inbound por mês (total)',
    (SELECT STRING_AGG(FORMAT('%s: %d', FORMAT_DATE('%Y-%m', mes), total), ' | ' ORDER BY mes) FROM t
     WHERE tipo = 'Inbound'), 'informativo', TRUE)
])

-- Validação de gold_monday.gld_agenciamento_atendimento_mensal (só leitura; view sobre a gld_agenciamento_entrada_diaria,
-- a gld_agenciamento_fluxo_mensal e a gld_agenciamento_2026_saidas_status). Rodar depois de criar a view, que vem depois
-- da gld_agenciamento_2026_saidas_status e da gld_agenciamento_fila_mensal. Toda linha deve sair com ok = TRUE. É view:
-- não entra no job.
-- Confere as contas de cada mês (veio + entradas = para atender; para atender − respondidos = ficou), a fila que recomeça
-- em janeiro (AM1), os externos (AM3), os meses sem buraco, o que ficou contra a gld_agenciamento_fila_mensal (no ano de
-- ontem) e a composição por status conferida em todo mês do ano de ontem.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_atendimento_mensal`
),

fila AS (
  SELECT mes, SUM(seguem) AS seguem
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fila_mensal`
  WHERE do_ano
  GROUP BY mes
),

ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

contas AS (
  SELECT *,
    LAG(ficou) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes) AS ficou_antes
  FROM t
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT mes) AS chaves,
    COUNTIF(entradas < 0 OR entregues < 0 OR sem_entrega < 0 OR sem_entrega_sem_data < 0 OR externos < 0
            OR sem_entrega_sem_data > sem_entrega) AS negativos,
    COUNTIF(respondidos != entregues + sem_entrega OR para_atender != veio + entradas
            OR ficou != para_atender - respondidos OR dependia != para_atender - externos) AS contas_erradas,
    COUNTIF(veio != IFNULL(ficou_antes, 0)) AS veio_errado,
    COUNTIF(EXTRACT(MONTH FROM mes) = 1 AND veio != 0) AS janeiro_com_fila,
    COUNTIF(externos > sem_entrega OR (NOT status_confere AND externos != 0)) AS externos_invalidos,
    COUNTIF(completo != (LAST_DAY(mes) <= o.dia)) AS completo_errado,
    COUNTIF(EXTRACT(YEAR FROM mes) = EXTRACT(YEAR FROM o.dia) AND NOT status_confere) AS ano_sem_status
  FROM contas, ontem o
),

contra_fila AS (
  SELECT COUNTIF(t.ficou != IFNULL(f.seguem, 0)) AS diferentes,
    STRING_AGG(IF(t.ficou != IFNULL(f.seguem, 0), FORMAT('%s: %d ≠ %d', FORMAT_DATE('%Y-%m', t.mes), t.ficou,
      IFNULL(f.seguem, 0)), NULL), ' | ' ORDER BY t.mes) AS texto
  FROM t
  CROSS JOIN ontem o
  LEFT JOIN fila f ON f.mes = t.mes
  WHERE EXTRACT(YEAR FROM t.mes) = EXTRACT(YEAR FROM o.dia)
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, contra_fila c, ontem o, UNNEST([
  STRUCT(
    'chave mês única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses de 2025-01 até o mês de ontem, sem buraco', CAST(r.linhas AS STRING),
    CAST(DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2025-01-01', MONTH) + 1 AS STRING),
    r.linhas = DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2025-01-01', MONTH) + 1),
  ('contagens negativas ou sem data acima das saídas sem entrega', CAST(r.negativos AS STRING), '0', r.negativos = 0),
  ('contas do mês (respondidos, para atender, ficou, dependia) que não fecham', CAST(r.contas_erradas AS STRING), '0',
    r.contas_erradas = 0),
  ('veio ≠ o que ficou no mês anterior do mesmo ano', CAST(r.veio_errado AS STRING), '0', r.veio_errado = 0),
  ('janeiro com fila vinda do ano anterior (AM1)', CAST(r.janeiro_com_fila AS STRING), '0', r.janeiro_com_fila = 0),
  ('externos acima das saídas sem entrega ou sem a composição conferida (AM3)', CAST(r.externos_invalidos AS STRING), '0',
    r.externos_invalidos = 0),
  ('completo errado (só o mês de ontem fica parcial)', CAST(r.completo_errado AS STRING), '0', r.completo_errado = 0),
  ('meses do ano de ontem sem a composição por status conferida', CAST(r.ano_sem_status AS STRING), '0',
    r.ano_sem_status = 0),
  ('ano de ontem: ficou ≠ seguem da gld_agenciamento_fila_mensal', IFNULL(c.texto, '0'), '0', c.diferentes = 0),
  ('mês de ontem: entradas | entregues | sem entrega | ficou | externos',
    (SELECT FORMAT('%d | %d | %d | %d | %d', entradas, entregues, sem_entrega, ficou, externos)
     FROM t WHERE mes = DATE_TRUNC(o.dia, MONTH)), 'informativo', TRUE)
])

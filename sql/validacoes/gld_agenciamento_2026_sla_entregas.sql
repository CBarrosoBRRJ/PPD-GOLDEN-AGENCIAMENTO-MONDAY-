-- Validação de gold_monday.gld_agenciamento_2026_sla_entregas (só leitura; view sobre a gld_agenciamento_2026_sla_movimentos).
-- Rodar depois de criar a view e quando a base mudar de regra. Toda linha deve sair com ok = TRUE. É view: não entra no job.
-- Confere a população contra a base (todo projeto com 1º passo com o cliente depois do passo 1, E1), a ordem das datas e
-- que as partes (fila, elaboração, revisão) nunca passam do trabalho (E2).
-- Aviso: horas todas zero = a coluna sla_sem_almoco_horas (R24) ainda não foi calculada pelo job (logo depois de criar a
-- coluna na SLA e antes da 1ª execução com o código novo).

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas`
),

m AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

-- E1 na base: projetos cujo 1º passo com o cliente vem depois do passo 1
esperados AS (
  SELECT projeto_id FROM m WHERE fase = 'cliente' GROUP BY projeto_id HAVING MIN(passo) > 1
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT projeto_id) AS chaves,
    COUNTIF(entregue_em < inicio OR inicio IS NULL OR entregue_em IS NULL) AS datas_invalidas,
    COUNTIF(mes != DATE_TRUNC(DATE(entregue_em), MONTH) OR mes_entrada != DATE_TRUNC(DATE(inicio), MONTH)) AS mes_errado,
    COUNTIF(h_trabalho IS NULL OR h_fila IS NULL OR h_elaboracao IS NULL OR h_revisao IS NULL OR h_calendario IS NULL
            OR h_trabalho < 0 OR h_fila < 0 OR h_elaboracao < 0 OR h_revisao < 0 OR dias_uteis < 0
            OR dias_uteis_fr < 0) AS horas_invalidas,
    COUNTIF(h_fila + h_elaboracao + h_revisao > h_trabalho + 1e-6) AS partes_acima,
    IFNULL(SUM(h_trabalho), 0) AS h_total,
    COUNTIF(mes = DATE_TRUNC(o.dia, MONTH)) AS no_mes,
    ROUND(AVG(IF(mes = DATE_TRUNC(o.dia, MONTH), h_trabalho, NULL)), 1) AS h_media_mes
  FROM t, ontem o
),

populacao AS (
  SELECT COUNT(*) AS diferentes
  FROM (SELECT projeto_id FROM t) x FULL JOIN esperados e USING (projeto_id)
  WHERE x.projeto_id IS NULL OR e.projeto_id IS NULL
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, populacao p, UNNEST([
  STRUCT(
    'chave projeto_id única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('projetos diferentes da base (1º passo com o cliente depois do passo 1, E1)', CAST(p.diferentes AS STRING), '0',
    p.diferentes = 0),
  ('entrega antes do pedido ou data vazia', CAST(r.datas_invalidas AS STRING), '0', r.datas_invalidas = 0),
  ('mes ou mes_entrada diferente do mês das datas', CAST(r.mes_errado AS STRING), '0', r.mes_errado = 0),
  ('horas ou dias nulos ou negativos', CAST(r.horas_invalidas AS STRING), '0', r.horas_invalidas = 0),
  ('fila + elaboração + revisão acima do trabalho (E2)', CAST(r.partes_acima AS STRING), '0', r.partes_acima = 0),
  ('horas sem almoço ainda não calculadas (R24 vazia na SLA)', CAST(IF(r.linhas > 0 AND r.h_total = 0, 1, 0) AS STRING),
    'aviso', TRUE),
  ('entregas no mês de ontem | média de horas de trabalho', FORMAT('%d | %t', r.no_mes, r.h_media_mes), 'informativo',
    TRUE)
])

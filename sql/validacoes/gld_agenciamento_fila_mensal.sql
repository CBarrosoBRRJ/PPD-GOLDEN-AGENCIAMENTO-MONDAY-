-- Validação de gold_monday.gld_agenciamento_fila_mensal (só leitura; view sobre a gld_agenciamento_fluxo_mensal).
-- Rodar depois de criar a view e quando a base mudar de regra. Toda linha deve sair com ok = TRUE. É view: não entra no job.
-- Confere o extrato de cada mês × safra do ano (aberto no início − saídas = segue no fim), a passagem de um mês para o
-- seguinte (o que segue vira represado), as safras de anos anteriores só com entregas (FM1), os meses sem buraco e o
-- total de entregas contra o fluxo.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fila_mensal`
),

f AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
),

ultimo AS (
  SELECT DATE_TRUNC(DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY), MONTH) AS mes FROM f
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, mes_entrada)) AS chaves,
    COUNT(DISTINCT mes) AS meses,
    COUNTIF(mes_entrada > mes OR mes != DATE_TRUNC(mes, MONTH) OR mes_entrada != DATE_TRUNC(mes_entrada, MONTH))
      AS datas_invalidas,
    COUNTIF(novos < 0 OR represados < 0 OR entregues < 0 OR nao_seguiram < 0 OR seguem < 0) AS negativos,
    COUNTIF(do_ano AND novos + represados - entregues - nao_seguiram != seguem) AS nao_fecha,
    COUNTIF(novos > 0 AND mes != mes_entrada) AS novos_fora_da_safra,
    COUNTIF(NOT do_ano AND (novos + represados + nao_seguiram + seguem > 0 OR entregues = 0)) AS fora_do_ano_invalido,
    SUM(entregues) AS entregues
  FROM t
),

passagem AS (
  SELECT COUNTIF(a.seguem != b.represados) AS diferentes
  FROM t a
  JOIN t b ON b.mes_entrada = a.mes_entrada AND b.mes = DATE_ADD(a.mes, INTERVAL 1 MONTH)
  WHERE a.do_ano AND b.do_ano
),

fluxo AS (
  SELECT SUM(quantidade) AS entregues
  FROM f, ultimo u
  WHERE evento = 'entregue' AND mes_evento BETWEEN DATE '2024-10-01' AND u.mes
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, passagem p, fluxo x, ultimo u, UNNEST([
  STRUCT(
    'chave mês × mês de entrada única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses de 2024-10 até o mês de ontem, sem buraco', CAST(r.meses AS STRING),
    CAST(DATE_DIFF(u.mes, DATE '2024-10-01', MONTH) + 1 AS STRING),
    r.meses = DATE_DIFF(u.mes, DATE '2024-10-01', MONTH) + 1),
  ('mês de entrada depois do mês ou datas que não são 1º dia', CAST(r.datas_invalidas AS STRING), '0',
    r.datas_invalidas = 0),
  ('contagens negativas', CAST(r.negativos AS STRING), '0', r.negativos = 0),
  ('safras do ano em que novos + represados − entregues − não seguiram ≠ seguem', CAST(r.nao_fecha AS STRING), '0',
    r.nao_fecha = 0),
  ('o que segue no fim do mês ≠ represado no mês seguinte (mesma safra, mesmo ano)', CAST(p.diferentes AS STRING), '0',
    p.diferentes = 0),
  ('novos fora do mês de entrada', CAST(r.novos_fora_da_safra AS STRING), '0', r.novos_fora_da_safra = 0),
  ('safras de anos anteriores com fila ou sem entrega (FM1)', CAST(r.fora_do_ano_invalido AS STRING), '0',
    r.fora_do_ano_invalido = 0),
  ('entregas = entregue do fluxo mensal com mês do evento de 2024-10 até o mês de ontem', CAST(r.entregues AS STRING),
    CAST(x.entregues AS STRING), r.entregues = x.entregues),
  ('mês de ontem: novos | represados | entregues | não seguiram | seguem',
    (SELECT FORMAT('%d | %d | %d | %d | %d', SUM(novos), SUM(represados), SUM(entregues), SUM(nao_seguiram), SUM(seguem))
     FROM t WHERE mes = u.mes), 'informativo', TRUE)
])

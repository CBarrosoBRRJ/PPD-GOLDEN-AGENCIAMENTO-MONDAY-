-- Validação de gold_monday.gld_agenciamento_fluxo_mensal (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job e
-- "aviso" vira WARNING quando o resultado não é 0, sem bloquear.
-- A tabela é conferida contra a gld_agenciamento_entrada_diaria, que tem as mesmas regras de card e é conferida, ela
-- própria, contra uma recontagem independente nas silvers. A conferência é no grão mês de entrada × grupo × tipo ×
-- família (entradas e as 4 situações) e, por mês, nas saídas. No job, as duas tabelas são calculadas na mesma
-- sessão e a diária vem antes: o job troca o nome das duas tabelas pelas temporárias da execução, então a conferência
-- é sempre entre os dois cálculos do mesmo momento.
-- Saídas: a diária conta também as entregas de cards que entraram antes de 2024-10-01 (safras fora desta tabela);
-- por isso, por mês, saídas da diária >= entregues desta tabela, e a diferença vai ao log.
-- Referência de 23/10/2026 (informativo): set/2026 733 entradas = 460 entregues no mês + 131 depois + 138 não
-- seguiu + 4 em andamento.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

-- entradas e situação por mês de entrada × grupo × tipo × família, nas duas tabelas
comparacao AS (
  SELECT
    COUNTIF(IFNULL(a.total, 0) != IFNULL(b.total, 0)) AS dif_total,
    COUNTIF(IFNULL(a.no_mes, 0) != IFNULL(b.no_mes, 0)) AS dif_no_mes,
    COUNTIF(IFNULL(a.depois, 0) != IFNULL(b.depois, 0)) AS dif_depois,
    COUNTIF(IFNULL(a.nao_seguiu, 0) != IFNULL(b.nao_seguiu, 0)) AS dif_nao_seguiu,
    COUNTIF(IFNULL(a.em_andamento, 0) != IFNULL(b.em_andamento, 0)) AS dif_em_andamento,
    COUNT(*) AS combinacoes
  FROM (
    SELECT mes_entrada AS mes, grupo_input, tipo_de_input, familia,
      SUM(quantidade) AS total,
      SUM(IF(evento = 'entregue' AND mes_evento = mes_entrada, quantidade, 0)) AS no_mes,
      SUM(IF(evento = 'entregue' AND mes_evento > mes_entrada, quantidade, 0)) AS depois,
      SUM(IF(evento = 'nao_seguiu', quantidade, 0)) AS nao_seguiu,
      SUM(IF(evento = 'em_andamento', quantidade, 0)) AS em_andamento
    FROM t
    GROUP BY 1, 2, 3, 4) a
  FULL JOIN (
    SELECT DATE_TRUNC(data, MONTH) AS mes, grupo_input, tipo_de_input, familia,
      SUM(quantidade + quantidade_estimada) AS total, SUM(entregue_no_mes) AS no_mes, SUM(entregue_depois) AS depois,
      SUM(nao_seguiu) AS nao_seguiu, SUM(em_andamento) AS em_andamento
    FROM d
    GROUP BY 1, 2, 3, 4
    HAVING SUM(quantidade + quantidade_estimada) > 0) b
  USING (mes, grupo_input, tipo_de_input, familia)
),

-- saídas por mês: entregues desta tabela (pelo mês do evento) × quantidade_saida da diária
saidas AS (
  SELECT
    mes,
    IFNULL(SUM(fluxo), 0) AS fluxo,
    IFNULL(SUM(diaria), 0) AS diaria
  FROM (
    SELECT mes_evento AS mes, quantidade AS fluxo, 0 AS diaria FROM t WHERE evento = 'entregue'
    UNION ALL
    SELECT DATE_TRUNC(data, MONTH), 0, quantidade_saida FROM d)
  GROUP BY mes
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%s|%t|%s|%s|%s', mes_entrada, evento, mes_evento, grupo_input, tipo_de_input, familia))
      AS chaves,
    COUNTIF(mes_entrada IS NULL OR evento IS NULL OR grupo_input IS NULL OR tipo_de_input IS NULL OR familia IS NULL
            OR quantidade IS NULL OR quantidade <= 0
            OR mes_entrada != DATE_TRUNC(mes_entrada, MONTH) OR mes_evento != DATE_TRUNC(mes_evento, MONTH)
            OR evento NOT IN ('entregue', 'nao_seguiu', 'em_andamento')) AS invalidas,
    COUNTIF(mes_entrada < DATE '2024-10-01'
            OR mes_entrada > DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), MONTH))
      AS fora_periodo,
    COUNTIF(mes_evento < mes_entrada) AS evento_antes_entrada,
    COUNTIF(mes_evento > DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), MONTH))
      AS evento_futuro,
    COUNTIF((evento = 'entregue' AND mes_evento IS NULL) OR (evento = 'em_andamento' AND mes_evento IS NOT NULL))
      AS mes_evento_incoerente,
    SUM(quantidade) AS cards,
    SUM(IF(evento = 'nao_seguiu' AND mes_evento IS NULL, quantidade, 0)) AS nao_seguiu_sem_mes
  FROM t
),

-- F3 e F4 recontados nas silvers do board 2026 (os boards 2024 e 2025 não têm log): cards ativos em status final
-- sem entrega válida até ontem, com a data de entrada da R21, e a última entrada no status atual pelo log
nao_seguiu_2026 AS (
  SELECT
    COUNTIF(ue.dia IS NULL) AS sem_log,
    COUNTIF(ue.dia IS NOT NULL AND DATE_TRUNC(ue.dia, MONTH) < DATE_TRUNC(c.entrada, MONTH)) AS antes_da_entrada
  FROM (
    SELECT i.projeto_id, i.status, i.entrada,
      CASE WHEN af.dia >= i.entrada THEN af.dia WHEN i.data_de_saida >= i.entrada THEN i.data_de_saida END AS saida
    FROM (
      SELECT projeto_id, status, data_de_saida,
        IF(data_de_saida < DATE(criado_em) AND data_de_entrada <= data_de_saida, data_de_entrada, DATE(criado_em))
          AS entrada
      FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens`
      WHERE state = 'active' AND criado_em IS NOT NULL) i
    LEFT JOIN (
      SELECT projeto_id, MIN(DATE(alterado_em)) AS dia
      FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
      WHERE campo_alterado = 'Status' AND valor_depois = 'Aguardando Feedback'
      GROUP BY projeto_id) af USING (projeto_id)) c
  LEFT JOIN (
    SELECT projeto_id, valor_depois, MAX(DATE(alterado_em)) AS dia
    FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
    WHERE campo_alterado = 'Status'
    GROUP BY projeto_id, valor_depois) ue
    ON ue.projeto_id = c.projeto_id AND ue.valor_depois = c.status
  WHERE c.entrada BETWEEN DATE '2024-10-01' AND DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY)
    AND (c.status LIKE 'Declinado%' OR c.status IN ('Standby', 'Encerrado'))
    AND NOT IFNULL(c.saida < CURRENT_DATE('America/Sao_Paulo'), FALSE)
),

-- referência: setembro/2026 como safra e como mês de entrega
setembro AS (
  SELECT
    SUM(IF(mes_entrada = DATE '2026-09-01', quantidade, 0)) AS entradas,
    SUM(IF(mes_entrada = DATE '2026-09-01' AND evento = 'entregue' AND mes_evento = mes_entrada, quantidade, 0)) AS no_mes,
    SUM(IF(mes_entrada = DATE '2026-09-01' AND evento = 'entregue' AND mes_evento > mes_entrada, quantidade, 0)) AS depois,
    SUM(IF(mes_entrada = DATE '2026-09-01' AND evento = 'nao_seguiu', quantidade, 0)) AS nao_seguiu,
    SUM(IF(mes_entrada = DATE '2026-09-01' AND evento = 'em_andamento', quantidade, 0)) AS em_andamento,
    SUM(IF(evento = 'entregue' AND mes_evento = DATE '2026-09-01', quantidade, 0)) AS entregas_no_mes,
    SUM(IF(evento = 'entregue' AND mes_evento = DATE '2026-09-01' AND mes_entrada < mes_evento, quantidade, 0))
      AS entregas_safras_anteriores
  FROM t
),

setembro_por_safra AS (
  SELECT IFNULL(STRING_AGG(FORMAT('%s: %d', FORMAT_DATE('%Y-%m', mes_entrada), n), ' | ' ORDER BY mes_entrada DESC),
                '0') AS safras
  FROM (
    SELECT mes_entrada, SUM(quantidade) AS n
    FROM t
    WHERE evento = 'entregue' AND mes_evento = DATE '2026-09-01' AND mes_entrada < mes_evento
    GROUP BY mes_entrada)
),

por_evento_ano AS (
  SELECT STRING_AGG(FORMAT('%d: entregue %d · não seguiu %d · em andamento %d', ano, e, n, a), ' | ' ORDER BY ano)
    AS texto
  FROM (
    SELECT EXTRACT(YEAR FROM mes_entrada) AS ano,
      SUM(IF(evento = 'entregue', quantidade, 0)) AS e,
      SUM(IF(evento = 'nao_seguiu', quantidade, 0)) AS n,
      SUM(IF(evento = 'em_andamento', quantidade, 0)) AS a
    FROM t
    GROUP BY ano)
),

sem_mes_por_ano AS (
  SELECT STRING_AGG(FORMAT('%d: %d', ano, n), ' | ' ORDER BY ano) AS texto
  FROM (
    SELECT EXTRACT(YEAR FROM mes_entrada) AS ano, SUM(quantidade) AS n
    FROM t
    WHERE evento = 'nao_seguiu' AND mes_evento IS NULL
    GROUP BY ano)
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, comparacao c, nao_seguiu_2026 n, setembro s, UNNEST([
  STRUCT(
    'chave mes_entrada × evento × mes_evento × grupo_input × tipo_de_input × familia única' AS verificacao,
    CAST(r.linhas - r.chaves AS STRING) AS resultado,
    '0' AS esperado,
    r.linhas = r.chaves AS ok),
  ('linhas inválidas (vazio, quantidade nula ou ≤ 0, mês fora do dia 1, evento desconhecido)',
    CAST(r.invalidas AS STRING), '0', r.invalidas = 0),
  ('mes_entrada antes de 2024-10 ou depois do mês de ontem', CAST(r.fora_periodo AS STRING), '0', r.fora_periodo = 0),
  ('mes_evento antes de mes_entrada (F4)', CAST(r.evento_antes_entrada AS STRING), '0', r.evento_antes_entrada = 0),
  ('mes_evento depois do mês de ontem', CAST(r.evento_futuro AS STRING), '0', r.evento_futuro = 0),
  ('mes_evento incoerente com o evento (entregue sem mês; em_andamento com mês)', CAST(r.mes_evento_incoerente AS STRING),
    '0', r.mes_evento_incoerente = 0),
  ('total de cards = entradas da diária (quantidade + quantidade_estimada)',
    CAST(r.cards AS STRING), (SELECT CAST(SUM(quantidade + quantidade_estimada) AS STRING) FROM d),
    r.cards = (SELECT SUM(quantidade + quantidade_estimada) FROM d)),
  ('= diária por mês de entrada × grupo × tipo × família: combinações diferentes (total | no mês | depois | não seguiu | em andamento)',
    FORMAT('%d | %d | %d | %d | %d', c.dif_total, c.dif_no_mes, c.dif_depois, c.dif_nao_seguiu, c.dif_em_andamento),
    '0 | 0 | 0 | 0 | 0',
    c.dif_total + c.dif_no_mes + c.dif_depois + c.dif_nao_seguiu + c.dif_em_andamento = 0),
  ('saídas por mês: entregues (mês do evento) ≤ quantidade_saida da diária: meses com mais entregues que saídas',
    IFNULL((SELECT STRING_AGG(FORMAT('%s: %d > %d', FORMAT_DATE('%Y-%m', mes), fluxo, diaria), ' | ' ORDER BY mes)
            FROM saidas WHERE fluxo > diaria), '0'),
    '0', (SELECT COUNTIF(fluxo > diaria) = 0 FROM saidas)),
  ('saídas da diária de cards com entrada antes de 2024-10-01 (diária − entregues), por mês',
    IFNULL((SELECT STRING_AGG(FORMAT('%s: %d', FORMAT_DATE('%Y-%m', mes), diaria - fluxo), ' | ' ORDER BY mes)
            FROM saidas WHERE diaria != fluxo), '0'),
    'informativo', TRUE),
  ('cards por evento e ano de entrada', (SELECT texto FROM por_evento_ano), 'informativo', TRUE),
  ('não seguiu sem mês do evento (F3), por ano de entrada', IFNULL((SELECT texto FROM sem_mes_por_ano), '0'),
    'informativo', TRUE),
  ('não seguiu sem mês do evento, por board (2026: sem log do status atual | 2024 e 2025: sem log, sempre NULL)',
    FORMAT('2026: %d | 2024 e 2025: %d', n.sem_log, r.nao_seguiu_sem_mes - n.sem_log), 'informativo', TRUE),
  ('não seguiu com o status final antes do mês de entrada, corrigido para o mês de entrada (F4; board 2026)',
    CAST(n.antes_da_entrada AS STRING), 'aviso', TRUE),
  ('referência set/2026 como safra: entradas = entregue no mês + depois + não seguiu + em andamento (23/10: 733 = 460 + 131 + 138 + 4)',
    FORMAT('%d = %d + %d + %d + %d', s.entradas, s.no_mes, s.depois, s.nao_seguiu, s.em_andamento), 'informativo', TRUE),
  ('referência set/2026 como mês de entrega: entregas = da safra de setembro + de safras anteriores',
    FORMAT('%d = %d + %d', s.entregas_no_mes, s.entregas_no_mes - s.entregas_safras_anteriores,
           s.entregas_safras_anteriores), 'informativo', TRUE),
  ('entregas em set/2026 de safras anteriores, por safra', (SELECT safras FROM setembro_por_safra), 'informativo', TRUE)
])

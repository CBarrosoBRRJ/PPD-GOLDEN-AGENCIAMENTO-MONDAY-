-- Validação de gold_monday.gld_agenciamento_entrada_diaria (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE.
-- As linhas "informativo" têm ok sempre TRUE: o job grava o resultado no log da execução (cards fora, estimados e
-- cards por família por ano). A linha "aviso" também não bloqueia, mas o job a grava como WARNING quando há tipo de
-- input novo (grupo Outros). A recontagem nas silvers é independente do SELECT: acha a data estimada por dias úteis
-- numerados em sequência.
-- Referência por ano de 22/10/2026 (quantidade + quantidade_estimada): 328 (2024), 3.577 (2025), 5.488 (2026) —
-- informativa. A trava fixa é por board histórico (decisão do Caio, 22/10/2026): os cards dos boards 2024 e 2025 que
-- têm data desde 2024-10-01 (327 e 3.578, sem o limite "até ontem") só mudam se a silver histórica for recarregada;
-- um card do board 2026 que caia em 2025 não a afeta.
-- A tabela é conferida contra a recontagem nas silvers dia a dia (reais, estimados e saídas separados).
-- Saída (R12–R14): recontada aqui de forma independente — a 1ª ida a Aguardando Feedback pela ordem dos eventos do log
-- (ROW_NUMBER por alterado_em e log_id), não pelo MIN do SELECT. A trava fixa das saídas também é por board histórico
-- (decisão do Caio, 23/10/2026): saídas dos boards 2024 e 2025 desde 2024-10-01, sem o limite "até ontem": 213 e 3.005.
-- Situação por safra (R16–R20): recontada aqui de forma independente (mês da saída × mês da entrada por FORMAT_DATE,
-- status por LIKE) e conferida dia a dia; a soma das 4 colunas = quantidade + quantidade_estimada em toda linha.
-- Referência de 23/10/2026 (aviso, não bloqueia): entradas 328 / 3.577 / ≥ 5.529 e saídas 204 / 3.012 / ≥ 4.276
-- (2024 / 2025 / 2026); meses fechados de 2026 (jan–set) com no máximo 20 em andamento por mês.

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

-- calendário sem expediente: o mesmo da gld_agenciamento_2026_sla_movimentos (R14 de lá) e do SELECT (R3)
anos AS (
  SELECT ano
  FROM UNNEST(GENERATE_ARRAY(2020, EXTRACT(YEAR FROM CURRENT_DATE('America/Sao_Paulo')) + 1)) AS ano
),

-- Domingo de Páscoa (algoritmo de Meeus/Jones/Butcher, calendário gregoriano)
pascoa AS (
  SELECT ano, DATE(ano, DIV(h + l - 7 * m + 114, 31), MOD(h + l - 7 * m + 114, 31) + 1) AS domingo
  FROM (
    SELECT ano, h, l, DIV(a + 11 * h + 22 * l, 451) AS m
    FROM (
      SELECT ano, a, h, MOD(32 + 2 * e + 2 * i - h - k, 7) AS l
      FROM (
        SELECT ano, a, e, i, k, MOD(19 * a + b - d - g + 15, 30) AS h
        FROM (
          SELECT
            ano,
            MOD(ano, 19) AS a,
            DIV(ano, 100) AS b,
            DIV(DIV(ano, 100), 4) AS d,
            MOD(DIV(ano, 100), 4) AS e,
            DIV(DIV(ano, 100) - DIV(DIV(ano, 100) + 8, 25) + 1, 3) AS g,
            DIV(MOD(ano, 100), 4) AS i,
            MOD(MOD(ano, 100), 4) AS k
          FROM anos))))
),

feriados AS (
  SELECT ARRAY_AGG(DISTINCT dia) AS dias
  FROM (
    -- datas fixas: nacionais, RJ (estado e cidade), SP (estado e cidade) e vésperas sem expediente
    SELECT DATE(ano, f.mes, f.dia) AS dia
    FROM anos,
      UNNEST(ARRAY<STRUCT<mes INT64, dia INT64>>[
        (1, 1),    -- Confraternização Universal
        (1, 20),   -- São Sebastião (cidade do RJ)
        (1, 25),   -- aniversário da cidade de SP
        (4, 21),   -- Tiradentes
        (4, 23),   -- São Jorge (estado do RJ)
        (5, 1),    -- Dia do Trabalho
        (7, 9),    -- Revolução Constitucionalista (estado de SP)
        (9, 7),    -- Independência
        (10, 12),  -- Nossa Senhora Aparecida
        (11, 2),   -- Finados
        (11, 15),  -- Proclamação da República
        (11, 20),  -- Consciência Negra
        (12, 24),  -- véspera de Natal
        (12, 25),  -- Natal
        (12, 31)   -- véspera de Ano-Novo
      ]) AS f
    UNION ALL
    -- datas móveis, pela Páscoa
    SELECT DATE_ADD(domingo, INTERVAL n DAY)
    FROM pascoa,
      UNNEST([
        -48,  -- segunda de Carnaval
        -47,  -- terça de Carnaval
        -46,  -- Quarta-feira de Cinzas
        -2,   -- Sexta-feira Santa
        60    -- Corpus Christi
      ]) AS n
    UNION ALL
    -- exceções pontuais (ex.: dia sem expediente decidido pela empresa); vazio por enquanto
    SELECT dia FROM UNNEST(ARRAY<DATE>[]) AS dia
  )
),

-- 1ª ida de cada projeto a Aguardando Feedback, pela ordem dos eventos (R12)
primeiro_af AS (
  SELECT projeto_id, DATE(alterado_em) AS dia
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE campo_alterado = 'Status' AND valor_depois = 'Aguardando Feedback'
  QUALIFY ROW_NUMBER() OVER (PARTITION BY projeto_id ORDER BY alterado_em, log_id) = 1
),

itens AS (
  SELECT '2024' AS board, FORMAT('2024-%s', item_id) AS chave, criado_em, data_de_saida, CAST(NULL AS DATE) AS af,
    status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2024_itens`
  UNION ALL
  SELECT '2025', FORMAT('2025-%s', item_id), criado_em, data_de_saida, NULL, status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2025_itens`
  UNION ALL
  SELECT '2026', FORMAT('2026-%s', i.projeto_id), DATE(i.criado_em), i.data_de_saida, a.dia, i.status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  LEFT JOIN primeiro_af a USING (projeto_id)
  WHERE i.state = 'active'
),

-- dias úteis numerados em sequência (seg–sex fora do calendário). Vai até a maior data_de_saida dos cards que
-- precisam de estimativa (a saída pode ser futura), com teto de hoje + 60 dias: saída além disso daria estimativa
-- depois de ontem, fora da tabela de qualquer jeito, e uma data absurda (9999-12-31) não explode o calendário
uteis AS (
  SELECT d, ROW_NUMBER() OVER (ORDER BY d) AS n
  FROM feriados f,
    UNNEST(GENERATE_DATE_ARRAY(DATE '2020-01-01', LEAST(
      GREATEST(CURRENT_DATE('America/Sao_Paulo'),
               (SELECT IFNULL(MAX(data_de_saida), CURRENT_DATE('America/Sao_Paulo')) FROM itens
                WHERE criado_em IS NULL AND data_de_saida IS NOT NULL)),
      DATE_ADD(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 60 DAY)))) AS d
  WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias)
),

-- o último dia útil antes da saída é o nº n; a data estimada é o dia útil nº n − 4
estimadas AS (
  SELECT x.chave, u2.d AS dia
  FROM (
    SELECT i.chave, MAX(u.n) AS n
    FROM itens i
    JOIN uteis u ON u.d < i.data_de_saida
    WHERE i.criado_em IS NULL AND i.data_de_saida IS NOT NULL
    GROUP BY i.chave) x
  JOIN uteis u2 ON u2.n = x.n - 4
),

silver AS (
  SELECT
    i.board, i.status, COALESCE(i.criado_em, e.dia) AS dia, e.dia IS NOT NULL AS estimada,
    -- R12–R14, escritas de novo: log se não for antes da criação; senão a coluna, com a mesma condição
    CASE
      WHEN i.af IS NOT NULL AND (i.criado_em IS NULL OR i.af >= i.criado_em) THEN i.af
      WHEN i.data_de_saida IS NOT NULL AND (i.criado_em IS NULL OR i.data_de_saida >= i.criado_em) THEN i.data_de_saida
    END AS saida,
    CASE
      WHEN i.af IS NOT NULL AND (i.criado_em IS NULL OR i.af >= i.criado_em) THEN 'log'
      WHEN i.data_de_saida IS NOT NULL AND (i.criado_em IS NULL OR i.data_de_saida >= i.criado_em) THEN 'coluna'
      WHEN i.af IS NOT NULL OR i.data_de_saida IS NOT NULL THEN 'antes da criação'
      ELSE 'sem saída'
    END AS origem_saida,
    i.af IS NOT NULL AND i.data_de_saida IS NOT NULL AND i.af != i.data_de_saida AS log_difere_coluna,
    -- data_de_saida regravada depois da 1ª entrega (reenvio): só dá para saber com log (board 2026)
    i.af IS NOT NULL AND (i.criado_em IS NULL OR i.af >= i.criado_em) AND i.data_de_saida > i.af AS saida_regravada
  FROM itens i
  LEFT JOIN estimadas e USING (chave)
),

-- R16–R19, escritas de novo: situação hoje de cada card que entrou no período, pela safra (mês da entrada). A saída
-- só conta até ontem, como na quantidade_saida
periodo AS (
  SELECT
    *,
    CASE
      WHEN saida IS NOT NULL AND saida < CURRENT_DATE('America/Sao_Paulo')
        THEN IF(FORMAT_DATE('%Y%m', saida) > FORMAT_DATE('%Y%m', dia), 'depois', 'no_mes')
      WHEN status LIKE 'Declinado%' OR status = 'Standby' OR status = 'Encerrado' THEN 'nao_seguiu'
      ELSE 'em_andamento'
    END AS situacao
  FROM silver
  WHERE dia BETWEEN DATE '2024-10-01' AND DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY)
),

periodo_saida AS (
  SELECT * FROM silver
  WHERE saida BETWEEN DATE '2024-10-01' AND DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY)
),

-- comparação por ano: tabela × silvers, separando data real e estimada
por_ano AS (
  SELECT
    ano,
    SUM(real_t) AS real_t, SUM(est_t) AS est_t,
    SUM(real_s) AS real_s, SUM(est_s) AS est_s
  FROM (
    SELECT EXTRACT(YEAR FROM data) AS ano, quantidade AS real_t, quantidade_estimada AS est_t, 0 AS real_s, 0 AS est_s
    FROM t
    UNION ALL
    SELECT EXTRACT(YEAR FROM dia), 0, 0, IF(estimada, 0, 1), IF(estimada, 1, 0)
    FROM periodo)
  GROUP BY ano
),

-- saídas por ano: tabela × recontagem
saida_por_ano AS (
  SELECT ano, SUM(n_t) AS n_t, SUM(n_s) AS n_s
  FROM (
    SELECT EXTRACT(YEAR FROM data) AS ano, quantidade_saida AS n_t, 0 AS n_s FROM t
    UNION ALL
    SELECT EXTRACT(YEAR FROM saida), 0, 1 FROM periodo_saida)
  GROUP BY ano
),

-- dias em que quantidade, quantidade_estimada ou quantidade_saida diferem da recontagem (dia a dia, não só por ano).
-- Dia só com saída tem entrada 0 na tabela e nenhuma linha na recontagem de entradas: IFNULL(…, 0) nos dois lados
divergencias AS (
  SELECT
    COUNTIF(IFNULL(a.reais, 0) != IFNULL(b.reais, 0)) AS dias_reais,
    COUNTIF(IFNULL(a.est, 0) != IFNULL(b.est, 0)) AS dias_est,
    COUNTIF(IFNULL(a.saidas, 0) != IFNULL(c.saidas, 0)) AS dias_saida
  FROM (SELECT data, SUM(quantidade) AS reais, SUM(quantidade_estimada) AS est, SUM(quantidade_saida) AS saidas
        FROM t GROUP BY data) a
  FULL JOIN (SELECT dia, COUNTIF(NOT estimada) AS reais, COUNTIF(estimada) AS est FROM periodo GROUP BY dia) b
    ON a.data = b.dia
  FULL JOIN (SELECT saida, COUNT(*) AS saidas FROM periodo_saida GROUP BY saida) c
    ON COALESCE(a.data, b.dia) = c.saida
),

-- dias em que alguma das 4 colunas de situação difere da recontagem
divergencias_situacao AS (
  SELECT COUNTIF(IFNULL(a.no_mes, 0) != IFNULL(b.no_mes, 0) OR IFNULL(a.depois, 0) != IFNULL(b.depois, 0)
                 OR IFNULL(a.nao_seguiu, 0) != IFNULL(b.nao_seguiu, 0)
                 OR IFNULL(a.em_andamento, 0) != IFNULL(b.em_andamento, 0)) AS dias
  FROM (SELECT data, SUM(entregue_no_mes) AS no_mes, SUM(entregue_depois) AS depois, SUM(nao_seguiu) AS nao_seguiu,
          SUM(em_andamento) AS em_andamento
        FROM t GROUP BY data) a
  FULL JOIN (SELECT dia, COUNTIF(situacao = 'no_mes') AS no_mes, COUNTIF(situacao = 'depois') AS depois,
               COUNTIF(situacao = 'nao_seguiu') AS nao_seguiu, COUNTIF(situacao = 'em_andamento') AS em_andamento
             FROM periodo GROUP BY dia) b
    ON a.data = b.dia
),

-- situação por ano de entrada (para o log): as 4 colunas, Encerrado sem saída válida (pendência de preenchimento do
-- board) e em andamento com entrada há mais de 60 dias
situacao_por_ano AS (
  SELECT
    EXTRACT(YEAR FROM dia) AS ano,
    COUNTIF(situacao = 'no_mes') AS no_mes,
    COUNTIF(situacao = 'depois') AS depois,
    COUNTIF(situacao = 'nao_seguiu') AS nao_seguiu,
    COUNTIF(situacao = 'em_andamento') AS em_andamento,
    COUNTIF(situacao = 'nao_seguiu' AND status = 'Encerrado') AS encerrado_sem_saida,
    COUNTIF(situacao = 'em_andamento'
            AND dia < DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 60 DAY)) AS andamento_60d
  FROM periodo
  GROUP BY ano
),

-- 2026 por mês de entrada, na tabela: referência de agosto e limite de em andamento nos meses fechados
mes_2026 AS (
  SELECT mes, SUM(quantidade + quantidade_estimada) AS total, SUM(entregue_no_mes) AS no_mes,
    SUM(entregue_depois) AS depois, SUM(nao_seguiu) AS nao_seguiu, SUM(em_andamento) AS em_andamento
  FROM t
  WHERE ano = 2026
  GROUP BY mes
),

-- referência por board histórico (carga única): cards de cada board com data (real ou estimada) desde 2024-10-01,
-- SEM o limite "até ontem" — assim a conta não muda com o passar dos dias, só se a silver histórica for recarregada.
-- Cards do board 2026 que caiam em 2025 não mexem nesta conta
por_board AS (
  SELECT COUNTIF(board = '2024') AS b2024, COUNTIF(board = '2025') AS b2025
  FROM silver WHERE dia >= DATE '2024-10-01'
),

-- mesma trava para as saídas dos boards históricos (desde 2024-10-01, sem o limite "até ontem")
saida_por_board AS (
  SELECT COUNTIF(board = '2024') AS b2024, COUNTIF(board = '2025') AS b2025
  FROM silver WHERE saida >= DATE '2024-10-01'
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%s|%s|%s', data, grupo_input, tipo_de_input, familia)) AS chaves,
    COUNTIF(data < DATE '2024-10-01' OR data > DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY)) AS fora_periodo,
    COUNTIF(data IS NULL OR grupo_input IS NULL OR tipo_de_input IS NULL OR familia IS NULL
            OR quantidade IS NULL OR quantidade_estimada IS NULL OR quantidade_saida IS NULL
            OR quantidade < 0 OR quantidade_estimada < 0 OR quantidade_saida < 0
            OR entregue_no_mes IS NULL OR entregue_depois IS NULL OR nao_seguiu IS NULL OR em_andamento IS NULL
            OR entregue_no_mes < 0 OR entregue_depois < 0 OR nao_seguiu < 0 OR em_andamento < 0
            OR quantidade + quantidade_estimada + quantidade_saida = 0
            OR ano IS DISTINCT FROM EXTRACT(YEAR FROM data) OR mes IS DISTINCT FROM EXTRACT(MONTH FROM data)
            OR inicio_semana IS DISTINCT FROM DATE_TRUNC(data, ISOWEEK) OR EXTRACT(DAYOFWEEK FROM inicio_semana) != 2
            OR dia_semana IS DISTINCT FROM ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'][
                 OFFSET(EXTRACT(DAYOFWEEK FROM data) - 1)]) AS invalidas,
    -- grupo coerente com o tipo (R7), escrito aqui de novo para não depender do SELECT
    COUNTIF(grupo_input IS DISTINCT FROM CASE
              WHEN tipo_de_input = 'Sem tipo' THEN 'Sem tipo'
              WHEN tipo_de_input IN ('Mercado', 'Inbound', 'Proativo') THEN tipo_de_input
              WHEN tipo_de_input IN ('ViU', 'Interna', 'Globo', 'ViU First', 'OTR (Oportunidade em Tempo Real)')
                THEN 'Internos'
              ELSE 'Outros'
            END) AS grupo_errado,
    -- R20: as 4 colunas de situação somam os cards que entraram na linha
    COUNTIF(entregue_no_mes + entregue_depois + nao_seguiu + em_andamento
            IS DISTINCT FROM quantidade + quantidade_estimada) AS soma_situacao_errada,
    SUM(quantidade_estimada) AS estimados,
    COUNTIF(quantidade + quantidade_estimada = 0) AS linhas_so_saida,
    SUM(IF(EXTRACT(YEAR FROM data) = 2024, quantidade + quantidade_estimada, 0)) AS total_2024,
    SUM(IF(EXTRACT(YEAR FROM data) = 2025, quantidade + quantidade_estimada, 0)) AS total_2025,
    SUM(IF(EXTRACT(YEAR FROM data) = 2026, quantidade + quantidade_estimada, 0)) AS total_2026
  FROM t
),

-- R7: tipos de input novos (grupo Outros), com a quantidade de cards; '0' se nenhum
outros AS (
  SELECT IFNULL(STRING_AGG(FORMAT('%s: %d', tipo_de_input, n), ' | ' ORDER BY tipo_de_input), '0') AS tipos
  FROM (
    SELECT tipo_de_input, SUM(quantidade + quantidade_estimada) AS n
    FROM t WHERE grupo_input = 'Outros' GROUP BY tipo_de_input)
),

fontes AS (
  SELECT
    (SELECT COUNTIF(dia < DATE '2024-10-01') FROM silver) AS antes_do_inicio,
    -- diagnóstico: cards que precisam de estimativa com saída além do teto do calendário (hoje + 60 dias)
    (SELECT COUNTIF(criado_em IS NULL AND data_de_saida > DATE_ADD(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 60 DAY))
     FROM itens) AS saida_alem_do_teto,
    (SELECT STRING_AGG(FORMAT('%s: %d', board, n), ' | ' ORDER BY board)
     FROM (SELECT board, COUNT(*) AS n FROM silver WHERE dia IS NULL GROUP BY board)) AS sem_data,
    -- R14: saída antes da criação (sem correção pelo log), por board
    (SELECT STRING_AGG(FORMAT('%s: %d', board, n), ' | ' ORDER BY board)
     FROM (SELECT board, COUNT(*) AS n FROM silver WHERE origem_saida = 'antes da criação' GROUP BY board))
      AS saida_antes_criacao,
    -- de onde veio a saída dos cards do board 2026
    (SELECT STRING_AGG(FORMAT('%s: %d', origem_saida, n), ' | ' ORDER BY origem_saida)
     FROM (SELECT origem_saida, COUNT(*) AS n FROM silver WHERE board = '2026' GROUP BY origem_saida))
      AS origem_saida_2026,
    (SELECT COUNTIF(log_difere_coluna) FROM silver) AS log_difere_coluna,
    -- R12: cards com a data_de_saida regravada depois da 1ª entrega, por board; 2024 e 2025 não têm log
    (SELECT STRING_AGG(IF(board = '2026', FORMAT('%s: %d', board, n), FORMAT('%s: sem log', board)), ' | ' ORDER BY board)
     FROM (SELECT board, COUNTIF(saida_regravada) AS n FROM silver GROUP BY board)) AS saida_regravada,
    -- R15: fechados sem entrega não têm saída; Declinado pelo Mercado sem saída, por board (ano do board)
    (SELECT STRING_AGG(FORMAT('%s: %d', board, n), ' | ' ORDER BY board)
     FROM (SELECT board, COUNT(*) AS n FROM silver
           WHERE status = 'Declinado pelo Mercado' AND saida IS NULL GROUP BY board)) AS declinado_mercado_sem_saida
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, fontes f, UNNEST([
  STRUCT(
    'chave data × grupo_input × tipo_de_input × familia única' AS verificacao,
    CAST(r.linhas - r.chaves AS STRING) AS resultado,
    '0' AS esperado,
    r.linhas = r.chaves AS ok),
  ('datas antes de 2024-10-01 ou depois de ontem', CAST(r.fora_periodo AS STRING), '0', r.fora_periodo = 0),
  ('linhas inválidas (vazio, negativo, linha sem card, dia da semana/ano/mês/início da semana errados)',
    CAST(r.invalidas AS STRING), '0', r.invalidas = 0),
  ('grupo_input incoerente com o tipo_de_input (R7)', CAST(r.grupo_errado AS STRING), '0', r.grupo_errado = 0),
  ('por ano: quantidade + quantidade_estimada = silvers pela data',
    (SELECT STRING_AGG(FORMAT('%d: %d + %d = %d', ano, real_t, est_t, real_t + est_t), ' | ' ORDER BY ano) FROM por_ano),
    (SELECT STRING_AGG(FORMAT('%d: %d + %d = %d', ano, real_s, est_s, real_s + est_s), ' | ' ORDER BY ano) FROM por_ano),
    (SELECT LOGICAL_AND(real_t = real_s AND est_t = est_s) FROM por_ano)),
  ('por ano: quantidade_saida = silvers pela data de saída (R12–R14)',
    (SELECT STRING_AGG(FORMAT('%d: %d', ano, n_t), ' | ' ORDER BY ano) FROM saida_por_ano),
    (SELECT STRING_AGG(FORMAT('%d: %d', ano, n_s), ' | ' ORDER BY ano) FROM saida_por_ano),
    (SELECT LOGICAL_AND(n_t = n_s) FROM saida_por_ano)),
  ('quantidade, quantidade_estimada e quantidade_saida = recontagem, dia a dia (dias diferentes: reais | estimados | saídas)',
    (SELECT FORMAT('%d | %d | %d', dias_reais, dias_est, dias_saida) FROM divergencias), '0 | 0 | 0',
    (SELECT dias_reais = 0 AND dias_est = 0 AND dias_saida = 0 FROM divergencias)),
  ('referência por board histórico: cards dos boards 2024 e 2025 na tabela (carga única)',
    (SELECT FORMAT('board 2024: %d | board 2025: %d', b2024, b2025) FROM por_board),
    'board 2024: 327 | board 2025: 3578',
    (SELECT b2024 = 327 AND b2025 = 3578 FROM por_board)),
  ('entregue_no_mes + entregue_depois + nao_seguiu + em_andamento = quantidade + quantidade_estimada (R20): linhas diferentes',
    CAST(r.soma_situacao_errada AS STRING), '0', r.soma_situacao_errada = 0),
  ('situação = recontagem, dia a dia (dias diferentes)', (SELECT CAST(dias AS STRING) FROM divergencias_situacao), '0',
    (SELECT dias = 0 FROM divergencias_situacao)),
  ('referência de 23/10/2026 por ano (entradas 328 | 3577 | ≥ 5529; saídas 204 | 3012 | ≥ 4276): anos diferentes',
    IFNULL((SELECT STRING_AGG(FORMAT('%d: entradas %d, saídas %d', ano, e, s), ' | ' ORDER BY ano)
            FROM (SELECT p.ano, p.real_t + p.est_t AS e, IFNULL(q.n_t, 0) AS s
                  FROM por_ano p LEFT JOIN saida_por_ano q USING (ano))
            WHERE (ano = 2024 AND (e != 328 OR s != 204)) OR (ano = 2025 AND (e != 3577 OR s != 3012))
               OR (ano = 2026 AND (e < 5529 OR s < 4276))), '0'),
    'aviso', TRUE),
  ('2026 jan–set: meses com mais de 20 em andamento', IFNULL((
      SELECT STRING_AGG(FORMAT('%d: %d', mes, em_andamento), ' | ' ORDER BY mes)
      FROM mes_2026 WHERE mes <= 9 AND em_andamento > 20), '0'), 'aviso', TRUE),
  ('2026 jan–set: em andamento por mês', (
      SELECT STRING_AGG(FORMAT('%d: %d', mes, em_andamento), ' | ' ORDER BY mes) FROM mes_2026 WHERE mes <= 9),
    'informativo', TRUE),
  ('agosto/2026: total = no mês + depois + não seguiu + em andamento', (
      SELECT FORMAT('%d = %d + %d + %d + %d', total, no_mes, depois, nao_seguiu, em_andamento)
      FROM mes_2026 WHERE mes = 8), 'informativo', TRUE),
  ('situação por ano de entrada (no mês | depois | não seguiu | em andamento)', (
      SELECT STRING_AGG(FORMAT('%d: %d | %d | %d | %d', ano, no_mes, depois, nao_seguiu, em_andamento), ' · '
                        ORDER BY ano)
      FROM situacao_por_ano), 'informativo', TRUE),
  ('Encerrado sem saída válida, por ano de entrada (pendência de preenchimento do board)', (
      SELECT STRING_AGG(FORMAT('%d: %d', ano, encerrado_sem_saida), ' | ' ORDER BY ano) FROM situacao_por_ano),
    'informativo', TRUE),
  ('em andamento com entrada há mais de 60 dias, por ano de entrada', (
      SELECT STRING_AGG(FORMAT('%d: %d', ano, andamento_60d), ' | ' ORDER BY ano) FROM situacao_por_ano),
    'informativo', TRUE),
  ('totais por ano (entradas)',
    FORMAT('2024: %d | 2025: %d | 2026: %d', r.total_2024, r.total_2025, r.total_2026), 'informativo', TRUE),
  ('fora: data antes de 2024-10-01', CAST(f.antes_do_inicio AS STRING), 'informativo', TRUE),
  ('fora: sem criado_em nem data_de_saida (por board)', IFNULL(f.sem_data, '0'), 'informativo', TRUE),
  ('referência por board histórico: saídas dos boards 2024 e 2025 na tabela (carga única)',
    (SELECT FORMAT('board 2024: %d | board 2025: %d', b2024, b2025) FROM saida_por_board),
    'board 2024: 213 | board 2025: 3005',
    (SELECT b2024 = 213 AND b2025 = 3005 FROM saida_por_board)),
  ('cards com data estimada', CAST(r.estimados AS STRING), 'informativo', TRUE),
  ('saídas por ano', (SELECT STRING_AGG(FORMAT('%d: %d', ano, n_t), ' | ' ORDER BY ano) FROM saida_por_ano),
    'informativo', TRUE),
  ('linhas só com saída (sem entrada no dia)', CAST(r.linhas_so_saida AS STRING), 'informativo', TRUE),
  ('fora: saída antes da criação, sem correção pelo log (por board, R14)', IFNULL(f.saida_antes_criacao, '0'),
    'informativo', TRUE),
  ('origem da saída, board 2026 (antes da criação | coluna | log | sem saída)', f.origem_saida_2026, 'informativo', TRUE),
  ('cards com 1ª ida a Aguardando Feedback diferente da data_de_saida (reentregas e edições)',
    CAST(f.log_difere_coluna AS STRING), 'informativo', TRUE),
  ('data_de_saida regravada depois da 1ª entrega (reenvio), por board; a saída fica na 1ª (R12)', f.saida_regravada,
    'informativo', TRUE),
  ('fora das saídas: Declinado pelo Mercado sem data de saída (por board)', IFNULL(f.declinado_mercado_sem_saida, '0'),
    'informativo', TRUE),
  ('cards a estimar com data_de_saida além de hoje + 60 dias (fora da estimativa)', CAST(f.saida_alem_do_teto AS STRING), 'aviso', TRUE),
  ('tipo_de_input novo, sem grupo (Outros): valores e cards', (SELECT tipos FROM outros), 'aviso', TRUE)
])

UNION ALL

-- total por família por ano (real + estimada), para conferência manual e para o log
SELECT
  FORMAT('família: %s (por ano)', familia),
  STRING_AGG(FORMAT('%d: %d', ano, n), ' | ' ORDER BY ano),
  'informativo',
  TRUE
FROM (
  SELECT familia, EXTRACT(YEAR FROM data) AS ano, SUM(quantidade + quantidade_estimada) AS n
  FROM t
  GROUP BY familia, ano)
GROUP BY familia

UNION ALL

-- saídas por família por ano, para conferência manual e para o log
SELECT
  FORMAT('família: %s (saídas por ano)', familia),
  STRING_AGG(FORMAT('%d: %d', ano, n), ' | ' ORDER BY ano),
  'informativo',
  TRUE
FROM (
  SELECT familia, EXTRACT(YEAR FROM data) AS ano, SUM(quantidade_saida) AS n
  FROM t
  WHERE quantidade_saida > 0
  GROUP BY familia, ano)
GROUP BY familia

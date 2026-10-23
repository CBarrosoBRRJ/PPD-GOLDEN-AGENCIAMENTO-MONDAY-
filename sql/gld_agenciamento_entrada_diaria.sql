-- gold_monday.gld_agenciamento_entrada_diaria
-- Contagem diária de cards criados (entrada) e entregues ao cliente (saída) nos boards de Agenciamento 2024, 2025 e
-- 2026, por grupo de input e família, para análise de tendência e previsão de demanda, e a situação hoje dos cards
-- que entraram em cada dia (safra: entregue no mês, depois, não seguiu, em andamento). Uma linha por data ×
-- grupo_input × tipo_de_input × familia, só quando há entrada ou saída (sem linhas com zero: quem consome completa o
-- calendário e faz os recortes).
-- Só leitura (SELECT). A gravação é feita pelo deploy/ (CREATE OR REPLACE TABLE ... AS este SELECT).
-- Regras R1–R20: docs/tabelas/gld_agenciamento_entrada_diaria.md. Colunas: sql/esquemas/.

WITH parametros AS (
  SELECT
    DATE '2024-10-01' AS inicio,                                         -- R4: antes disso fica fora
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,  -- R4: até ontem (último dia fechado)
    5 AS dias_uteis_estimativa                                           -- R2: dias úteis antes da data_de_saida
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_2026_sla_movimentos (R14 de lá), calculado por ano
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

-- R12: 1ª entrada em Aguardando Feedback de cada projeto do board 2026, pelo log (a data_de_saida é regravada pela
-- automação a cada nova ida ao cliente; o log guarda a primeira, que não muda depois)
aguardando_feedback AS (
  SELECT projeto_id, MIN(DATE(alterado_em)) AS dia
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE campo_alterado = 'Status' AND valor_depois = 'Aguardando Feedback'
  GROUP BY projeto_id
),

-- os três boards no mesmo formato. R1: data real = criado_em (2024/2025) ou DATE(criado_em) (2026); nunca o
-- created_at de 2024/2025 (data da importação). R5: 2026 só state = 'active'. Os boards 2024 e 2025 não têm log
itens AS (
  SELECT criado_em, data_de_saida, CAST(NULL AS DATE) AS aguardando_feedback, tipo_de_input, tipo_de_output,
    item_name AS nome, marca, status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2024_itens`
  UNION ALL
  SELECT criado_em, data_de_saida, NULL, tipo_de_input, tipo_de_output, item_name, marca, status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2025_itens`
  UNION ALL
  SELECT DATE(i.criado_em), i.data_de_saida, af.dia, i.tipo_de_input, i.tipo_de_output, i.nome_projeto, i.marca,
    i.status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  LEFT JOIN aguardando_feedback af USING (projeto_id)
  WHERE i.state = 'active'
),

cards AS (
  SELECT
    -- R2: sem criado_em e com data_de_saida = data estimada: data_de_saida − 5 dias úteis (seg–sex fora do
    -- calendário R3; a janela de 21 dias cobre o Carnaval). Sem as duas datas = NULL (fica fora)
    COALESCE(i.criado_em, (
      SELECT ARRAY_AGG(d ORDER BY d DESC)[OFFSET(pr.dias_uteis_estimativa - 1)]
      FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(i.data_de_saida, INTERVAL 21 DAY),
                                      DATE_SUB(i.data_de_saida, INTERVAL 1 DAY))) AS d
      WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6
        AND d NOT IN UNNEST(f.dias))) AS dia,
    i.criado_em IS NULL AND i.data_de_saida IS NOT NULL AS estimada,
    -- R12–R14: saída = 1ª entrada em Aguardando Feedback pelo log (board 2026); sem ela, a data_de_saida. A que cair
    -- antes da criação não vale; sem nenhuma das duas válida = NULL (fica fora; a validação conta no log)
    CASE
      WHEN i.aguardando_feedback >= i.criado_em OR (i.aguardando_feedback IS NOT NULL AND i.criado_em IS NULL)
        THEN i.aguardando_feedback
      WHEN i.data_de_saida >= i.criado_em OR i.criado_em IS NULL THEN i.data_de_saida
    END AS saida,
    i.status,
    i.tipo_de_input,
    i.tipo_de_output,
    -- R8: texto de busca como na silver: sem acento e minúsculo
    LOWER(REGEXP_REPLACE(NORMALIZE(IFNULL(i.nome, ''), NFKD), r'\p{M}', '')) AS nome,
    LOWER(REGEXP_REPLACE(NORMALIZE(IFNULL(i.marca, ''), NFKD), r'\p{M}', '')) AS marca
  FROM itens i
  CROSS JOIN parametros pr
  CROSS JOIN feriados f
),

classificados AS (
  SELECT
    c.dia,
    c.estimada,
    c.saida,
    -- R16–R19: situação hoje do card na safra (o dia da entrada). Saída válida = a da quantidade_saida (R12–R15),
    -- só até ontem; a do mesmo mês ou de antes (só card de data estimada) = no mês. Sem saída: Declinado (qualquer
    -- variante), Standby ou Encerrado = não seguiu; o resto (inclusive status vazio) = em andamento
    CASE
      WHEN c.saida <= pr.fim
        THEN IF(DATE_TRUNC(c.saida, MONTH) <= DATE_TRUNC(c.dia, MONTH), 'no_mes', 'depois')
      WHEN STARTS_WITH(c.status, 'Declinado') OR c.status IN ('Standby', 'Encerrado') THEN 'nao_seguiu'
      ELSE 'em_andamento'
    END AS situacao,
    -- R7: grupo do input; vazio = Sem tipo; tipo novo = Outros (vai ao log pela validação)
    CASE
      WHEN c.tipo_de_input IS NULL THEN 'Sem tipo'
      WHEN c.tipo_de_input IN ('Mercado', 'Inbound', 'Proativo') THEN c.tipo_de_input
      WHEN c.tipo_de_input IN ('ViU', 'Interna', 'Globo', 'ViU First', 'OTR (Oportunidade em Tempo Real)') THEN 'Internos'
      ELSE 'Outros'
    END AS grupo_input,
    COALESCE(c.tipo_de_input, 'Sem tipo') AS tipo_de_input,
    -- R8 + R9: família pelo nome/marca (mesmo método nos três anos) e pelos 3 tipos de output da SLA; marca, não
    -- filtra. Card com mais de uma família fica com a primeira desta ordem (R9)
    CASE
      WHEN REGEXP_CONTAINS(REGEXP_REPLACE(c.nome, r'[^a-z0-9]', ''), r'upfront')
        OR REGEXP_CONTAINS(REGEXP_REPLACE(c.marca, r'[^a-z0-9]', ''), r'upfront') THEN 'Upfront'
      WHEN REGEXP_CONTAINS(c.nome, r'\blevop\b') THEN 'Levop'
      WHEN REGEXP_CONTAINS(c.nome, r'\b(?:midia|media)[\s_-]*kits?\b') THEN 'Mídia Kit'
      WHEN REGEXP_CONTAINS(c.nome, r'\b(?:analises?|abalise|aalise)\b') THEN 'Análise'
      WHEN REGEXP_CONTAINS(c.nome, r'\bdefesas?\b') THEN 'Defesa'
      WHEN REGEXP_CONTAINS(c.nome, r'\bcurador(?:ias?|as?|es)?\b') THEN 'Curadoria'
      WHEN c.tipo_de_output = 'Levop | Card de Oportunidade | Informação por e-mail' THEN 'Card de Oportunidade (Levop)'
      WHEN c.tipo_de_output = 'Curadoria Orçada' THEN 'Curadoria Orçada'
      WHEN c.tipo_de_output = 'Defesas | Estudo Comercial | Curadorias' THEN 'Defesas | Estudo Comercial'
      -- R8: variantes antigas de tipo de output (boards 2024/2025) = família equivalente, para a regra ser igual
      -- nos três anos
      WHEN c.tipo_de_output = 'Levop | Boletim Informativo/Boletim de efeméride' THEN 'Levop'
      WHEN c.tipo_de_output = 'Midia Kits' THEN 'Mídia Kit'
      WHEN c.tipo_de_output = 'Defesa | Análise | Estudo Comercial' THEN 'Defesas | Estudo Comercial'
      ELSE 'Nenhuma'
    END AS familia
  FROM cards c
  CROSS JOIN parametros pr
),

-- cada card vale até dois eventos: a entrada na data dele e a saída na data dela, cada um contado só se cair de
-- 2024-10-01 até ontem (R2 + R4 + R15; R6: conta pela data, não pelo board). O grupo e a família são os do card
eventos AS (
  SELECT c.dia AS data, c.grupo_input, c.tipo_de_input, c.familia,
    IF(c.estimada, 0, 1) AS real, IF(c.estimada, 1, 0) AS estimada, 0 AS saida,
    IF(c.situacao = 'no_mes', 1, 0) AS no_mes, IF(c.situacao = 'depois', 1, 0) AS depois,
    IF(c.situacao = 'nao_seguiu', 1, 0) AS nao_seguiu, IF(c.situacao = 'em_andamento', 1, 0) AS em_andamento
  FROM classificados c
  CROSS JOIN parametros pr
  WHERE c.dia BETWEEN pr.inicio AND pr.fim
  UNION ALL
  SELECT c.saida, c.grupo_input, c.tipo_de_input, c.familia, 0, 0, 1, 0, 0, 0, 0
  FROM classificados c
  CROSS JOIN parametros pr
  WHERE c.saida BETWEEN pr.inicio AND pr.fim
)

-- R10 + R15: só as combinações com entrada ou saída; sem linhas com zero
SELECT
  data,
  -- R11: dia da semana abreviado em português, ano, mês e a segunda-feira que inicia a semana
  ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'][OFFSET(EXTRACT(DAYOFWEEK FROM data) - 1)] AS dia_semana,
  EXTRACT(YEAR FROM data) AS ano,
  EXTRACT(MONTH FROM data) AS mes,
  DATE_TRUNC(data, ISOWEEK) AS inicio_semana,
  grupo_input,
  tipo_de_input,
  familia,
  SUM(real) AS quantidade,
  SUM(estimada) AS quantidade_estimada,
  SUM(saida) AS quantidade_saida,
  -- R16–R20: situação hoje dos cards que entraram no dia (quantidade + quantidade_estimada); foto do dia
  SUM(no_mes) AS entregue_no_mes,
  SUM(depois) AS entregue_depois,
  SUM(nao_seguiu) AS nao_seguiu,
  SUM(em_andamento) AS em_andamento,
  CURRENT_TIMESTAMP() AS _processado_em
FROM eventos
GROUP BY data, dia_semana, ano, mes, inicio_semana, grupo_input, tipo_de_input, familia

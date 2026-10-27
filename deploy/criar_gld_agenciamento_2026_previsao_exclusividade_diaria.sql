-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_2026_previsao_exclusividade_diaria.sql e sql/esquemas/gld_agenciamento_2026_previsao_exclusividade_diaria.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Recria a tabela inteira (CREATE OR REPLACE): seguro repetir; não apaga nada fora desta tabela.

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
(
  data DATE OPTIONS(description="Dia de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), todo dia de 1º/jan até ontem, com zero quando não há pedido. Com tipo, forma a chave"),
  tipo STRING OPTIONS(description="Tipo de input da silver: Inbound ou Mercado (as séries da previsão de demanda)"),
  dia_util BOOL OPTIONS(description="TRUE = segunda a sexta fora do calendário sem expediente (feriados nacionais, RJ, SP, Carnaval, Cinzas, Sexta-feira Santa, Corpus Christi e vésperas de Natal e Ano-Novo)"),
  exclusivos INT64 OPTIONS(description="Pedidos com talento exclusivo na data do pedido"),
  nao_exclusivos INT64 OPTIONS(description="Pedidos com talento não exclusivo na data do pedido (inclui Squad de Talentos)"),
  sem_talento INT64 OPTIONS(description="Pedidos sem exclusividade definida na silver (sem talento)"),
  total INT64 OPTIONS(description="exclusivos + nao_exclusivos + sem_talento; igual às entradas do dia e tipo na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução")
)
CLUSTER BY data, tipo
OPTIONS(
  description="Pedidos do board 2026 por dia de entrada e tipo de input (Inbound, Mercado), divididos em exclusivos, não exclusivos e sem talento (exclusividade na data do pedido), todo dia de 1º/jan até ontem, com zero quando não há pedido; dia_util marca seg–sex fora dos feriados. O total de cada dia e tipo é igual às entradas da gld_agenciamento_entrada_diaria. Base das séries da previsão de demanda (a mensal é view sobre esta). Uma linha por dia × tipo. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "previsao-exclusividade-diaria")]
)
AS
-- gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria — pedidos do ano por dia e tipo de input (Inbound, Mercado), divididos
-- em exclusivos, não exclusivos e sem talento. Board 2026. Ficha: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md.
-- Base da previsão de exclusividade: a gld_agenciamento_2026_previsao_exclusividade_mensal (view) soma esta tabela por mês. Origem: contrato previsao_exclusividade
-- do PPD-AGENCIAMENTO-SLA (auditoria de 26/10/2026), série de exclusividade de ml/dados.py do site (página Previsão).
-- Mesma população e regras de data e de exclusividade da gld_agenciamento_2026_talentos_ano.
-- PD1: calendário completo — todo dia de 1º/jan até ontem, nos dois tipos, com zero quando não há pedido (diferente
-- das outras golds, que não gravam zeros: aqui a série é o produto, e a mensal nunca fica com buraco).
WITH parametros AS (
  SELECT
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,                    -- R4: até ontem
    DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR) AS inicio
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_entrada_diaria (copiado igual; serve à data estimada R2)
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

pedidos AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(
      IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
         DATE(i.criado_em)),
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(i.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(i.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    i.talento,
    i.tipo_de_input,
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

-- PD1: todos os dias do ano até ontem × os dois tipos da previsão (P2)
calendario AS (
  SELECT dia, tipo, NOT (EXTRACT(DAYOFWEEK FROM dia) IN (1, 7) OR dia IN UNNEST(f.dias)) AS dia_util
  FROM parametros pr
  CROSS JOIN feriados f
  CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(pr.inicio, pr.fim)) AS dia
  CROSS JOIN UNNEST(['Inbound', 'Mercado']) AS tipo
),

contagem AS (
  SELECT
    p.dia,
    p.tipo_de_input AS tipo,
    COUNTIF(p.exclusivo) AS exclusivos,
    COUNTIF(NOT p.exclusivo) AS nao_exclusivos,
    COUNTIF(p.exclusivo IS NULL) AS sem_talento,
    COUNT(*) AS total
  FROM pedidos p CROSS JOIN parametros pr
  WHERE p.dia BETWEEN pr.inicio AND pr.fim                                   -- R4: até ontem
    AND p.tipo_de_input IN ('Inbound', 'Mercado')                           -- P2: as séries da previsão
  GROUP BY p.dia, tipo
)

SELECT
  c.dia AS data,
  c.tipo,
  -- PD2: dia útil = seg–sex fora do calendário sem expediente (R3), para os modelos separarem fim de semana e feriado
  c.dia_util,
  IFNULL(n.exclusivos, 0) AS exclusivos,
  IFNULL(n.nao_exclusivos, 0) AS nao_exclusivos,
  IFNULL(n.sem_talento, 0) AS sem_talento,
  IFNULL(n.total, 0) AS total,
  CURRENT_TIMESTAMP() AS _processado_em
FROM calendario c
LEFT JOIN contagem n USING (dia, tipo)
;

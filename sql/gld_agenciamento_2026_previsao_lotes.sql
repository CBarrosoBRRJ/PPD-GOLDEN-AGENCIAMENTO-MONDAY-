-- gold_monday.gld_agenciamento_2026_previsao_lotes — pedidos do ano por dia e recorte da previsão (inbound, mercado,
-- mercado_exclusivos, mercado_nao_exclusivos), separados em pedidos em lote e avulsos. Board 2026.
-- Ficha: docs/tabelas/gld_agenciamento_2026_previsao_lotes.md.
-- Origem: contrato previsao_lotes da auditoria do PPD-AGENCIAMENTO-SLA (26/10/2026), que reproduz _sql_lotes de
-- ml/dados.py do site (S6, D56 item 3: diagnóstico do mês em andamento). Mesma população e regras de data e de
-- exclusividade da gld_agenciamento_2026_talentos_ano. Por dia (e não "4 meses até o dia N" como no site): quem lê soma
-- o período que quiser, inclusive até o mesmo dia de cada mês. Só dias com pedido no recorte.
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
    -- L1: marca da coluna; sem ela, o prefixo [Marca] do nome do projeto
    COALESCE(i.marca, REGEXP_EXTRACT(i.nome_projeto, r'^\[([^\]]+)\]')) AS marca,
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

recortes AS (
  -- L2: um pedido entra no recorte do seu tipo e, se for Mercado com exclusividade definida, também no recorte dela
  SELECT p.dia, p.marca, r AS recorte
  FROM pedidos p
  CROSS JOIN parametros pr
  CROSS JOIN UNNEST(ARRAY_CONCAT(
      IF(p.tipo_de_input = 'Inbound', ['inbound'], []),
      IF(p.tipo_de_input = 'Mercado', ['mercado'], []),
      IF(p.tipo_de_input = 'Mercado' AND p.exclusivo, ['mercado_exclusivos'], []),
      IF(p.tipo_de_input = 'Mercado' AND NOT p.exclusivo, ['mercado_nao_exclusivos'], []))) AS r
  WHERE p.dia BETWEEN pr.inicio AND pr.fim                                   -- R4: até ontem
),

-- L3: lote = 3 ou mais pedidos do recorte com a mesma marca no mesmo dia; sem marca, nunca é lote
grupos AS (
  SELECT recorte, dia, marca, COUNT(*) AS n
  FROM recortes
  GROUP BY recorte, dia, marca
)

SELECT
  dia AS data,
  recorte,
  SUM(n) AS pedidos,
  SUM(IF(marca IS NOT NULL AND n >= 3, n, 0)) AS em_lote,
  SUM(IF(marca IS NOT NULL AND n >= 3, 0, n)) AS avulsos,
  COUNTIF(marca IS NOT NULL AND n >= 3) AS lotes,
  CURRENT_TIMESTAMP() AS _processado_em
FROM grupos
GROUP BY data, recorte

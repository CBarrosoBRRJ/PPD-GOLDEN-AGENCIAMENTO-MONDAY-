-- gold_monday.gld_agenciamento_2026_talentos_ano — divisão anual dos pedidos entre exclusivos, não exclusivos e sem
-- talento (board 2026). Ficha: docs/tabelas/gld_agenciamento_2026_talentos_ano.md.
-- Origem: tools/preparar_gold_relatorio.py do PPD-AGENCIAMENTO-SLA (contrato talentos_ano, auditoria de 26/10/2026),
-- que reproduz app/sql/talentos_ano.sql do site (exceção D30-b de lá). Mesma população e mesmas regras de data da
-- gld_agenciamento_entrada_diaria (R1, R2, R4, R5, R21), mas só o board 2026: a exclusividade só existe nele.
-- O ano é o de ontem; conta de 1º/jan até ontem. Percentuais com 1 casa, fechando 100,0% pelo maior resto.
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
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

contagem AS (
  SELECT
    EXTRACT(YEAR FROM p.dia) AS ano,
    CASE
      WHEN p.exclusivo THEN 'Exclusivos'
      WHEN NOT p.exclusivo THEN 'Não exclusivos'      -- inclui "Squad de Talentos" (regra 60 da silver)
      ELSE 'Sem talento'
    END AS categoria,
    COUNT(*) AS n,
    COUNTIF(p.talento = 'Squad de Talentos') AS dos_quais_squad
  FROM pedidos p
  CROSS JOIN parametros pr
  WHERE p.dia BETWEEN pr.inicio AND pr.fim                                   -- R4: até ontem
  GROUP BY ano, categoria
),

-- maior resto: décimos de ponto percentual (1000 = 100,0%)
partes AS (
  SELECT *, SUM(n) OVER () AS total,
    DIV(n * 1000, SUM(n) OVER ()) AS base,
    MOD(n * 1000, SUM(n) OVER ()) AS resto
  FROM contagem
)

SELECT
  ano,
  categoria,
  n,
  total,
  (base + IF(ROW_NUMBER() OVER (ORDER BY resto DESC, n DESC) <= 1000 - SUM(base) OVER (), 1, 0)) / 10 AS pct,
  dos_quais_squad,
  CURRENT_TIMESTAMP() AS _processado_em
FROM partes

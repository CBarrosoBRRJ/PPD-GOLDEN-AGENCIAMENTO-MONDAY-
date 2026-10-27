-- gold_monday.gld_agenciamento_2026_talentos_ranking — os 10 talentos com mais pedidos no ano em cada recorte
-- (todos, exclusivo, nao-exclusivo), mês a mês, e quem passou pelos 10 do acumulado (corrida do ano). Board 2026.
-- Ficha: docs/tabelas/gld_agenciamento_2026_talentos_ranking.md.
-- Origem: tools/preparar_gold_relatorio.py do PPD-AGENCIAMENTO-SLA (contrato talentos_ranking, auditoria de
-- 26/10/2026), que reproduz app/sql/talentos_top.sql do site (D50, D51). Mesma população e regras de data da
-- gld_agenciamento_2026_talentos_ano: o mês do pedido é o mês da data de entrada.
-- Um talento por pedido (duplas como "Bruno e Marrone" são um talento). Nomes agrupados sem diferença de maiúsculas e
-- espaços e mostrados na grafia mais frequente; "Squad de Talentos" (um grupo) e pedido sem talento ficam fora.
-- "todos" = exclusivos + não exclusivos pelo mesmo nome (quem mudou de vínculo no ano soma os dois). Empate: alfabética.
-- empate_fora: talentos fora da lista com o mesmo número de pedidos do 10º lugar ("empate com mais N" na tela).
-- Uma linha por (grupo, talento, mês com pedido); n = pedidos no ano, n_mes = no mês, talentos_grupo = talentos com
-- pedido no ano no recorte, pos = lugar no ano. Além dos 10 do ano (pos <= 10), vêm os que estiveram entre os 10 do
-- ACUMULADO no fim de algum mês (pos > 10); ranking do acumulado com desempate pelo lugar no ano.
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

-- pedidos do ano com talento nomeado, já no recorte (um pedido entra no seu grupo e em "todos")
validos AS (
  SELECT g AS grupo, p.dia, DATE_TRUNC(p.dia, MONTH) AS mes,
    LOWER(REGEXP_REPLACE(TRIM(p.talento), r'\s+', ' ')) AS chave,
    REGEXP_REPLACE(TRIM(p.talento), r'\s+', ' ') AS talento
  FROM pedidos p
  CROSS JOIN parametros pr
  CROSS JOIN UNNEST([IF(p.exclusivo, 'exclusivo', 'nao-exclusivo'), 'todos']) AS g
  WHERE p.dia BETWEEN pr.inicio AND pr.fim AND p.exclusivo IS NOT NULL
    AND LOWER(REGEXP_REPLACE(TRIM(COALESCE(p.talento, '')), r'\s+', ' ')) NOT IN ('', 'squad de talentos')
),

grafias AS (
  SELECT grupo, chave, talento, COUNT(*) AS n, MAX(dia) AS ultimo_pedido
  FROM validos GROUP BY grupo, chave, talento
),
ranking AS (
  SELECT grupo, chave, ARRAY_AGG(talento ORDER BY n DESC, talento LIMIT 1)[OFFSET(0)] AS talento,
    SUM(n) AS n, MAX(ultimo_pedido) AS ultimo_pedido
  FROM grafias GROUP BY grupo, chave
),

ranqueado AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY grupo ORDER BY n DESC, talento) AS pos,
    COUNT(*) OVER (PARTITION BY grupo) AS talentos_grupo                      -- talentos com pedido no ano, no recorte
  FROM ranking
),
fora AS (
  SELECT x.grupo, COUNT(*) AS empate_fora
  FROM ranqueado x JOIN ranqueado c ON c.grupo = x.grupo AND c.pos = 10 AND x.n = c.n
  WHERE x.pos > 10
  GROUP BY x.grupo
),

por_mes AS (
  SELECT grupo, chave, mes, COUNT(*) AS n_mes FROM validos GROUP BY grupo, chave, mes
),

-- D51: acumulado de cada talento no fim de cada mês do ano (meses com pedido no recorte) e quem passou pelos 10
acumulado AS (
  SELECT ms.grupo, ms.mes, r.chave, r.pos, SUM(IF(m.mes <= ms.mes, m.n_mes, 0)) AS ate_o_mes
  FROM (SELECT DISTINCT grupo, mes FROM validos) ms
  JOIN ranqueado r ON r.grupo = ms.grupo
  JOIN por_mes m ON m.grupo = r.grupo AND m.chave = r.chave
  GROUP BY ms.grupo, ms.mes, r.chave, r.pos
),
na_corrida AS (
  SELECT DISTINCT grupo, chave
  FROM (SELECT grupo, chave, ROW_NUMBER() OVER (PARTITION BY grupo, mes ORDER BY ate_o_mes DESC, pos) AS lugar
        FROM acumulado)
  WHERE lugar <= 10
)

SELECT r.grupo, r.talento, r.n, r.ultimo_pedido, COALESCE(f.empate_fora, 0) AS empate_fora, r.talentos_grupo, m.mes,
  m.n_mes, r.pos, CURRENT_TIMESTAMP() AS _processado_em
FROM ranqueado r
LEFT JOIN fora f USING (grupo)
LEFT JOIN na_corrida c ON c.grupo = r.grupo AND c.chave = r.chave
JOIN por_mes m ON m.grupo = r.grupo AND m.chave = r.chave
WHERE r.pos <= 10 OR c.chave IS NOT NULL

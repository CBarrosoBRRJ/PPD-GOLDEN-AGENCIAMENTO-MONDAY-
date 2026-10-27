-- gold_monday.gld_agenciamento_2026_saidas_status — composição por STATUS do board das saídas sem entrega
-- (Declinado*, Standby, Encerrado) dos pedidos que entraram no ano, por mês do evento. Board 2026.
-- Ficha: docs/tabelas/gld_agenciamento_2026_saidas_status.md.
-- Origem: tools/preparar_gold_relatorio.py do PPD-AGENCIAMENTO-SLA (contrato atendimento_status, auditoria de
-- 26/10/2026), que reproduz app/sql/saidas_status.sql do site (A26, D53). Lê só a silver (itens + log) com as mesmas
-- regras da gld_agenciamento_fluxo_mensal para o evento nao_seguiu (R1, R2, R4, R5, R12–R14, R16–R19, R21, F3, F4):
-- o fluxo não guarda o status, por isso esta tabela existe.
-- Mês do evento = mês em que o card chegou ao status final (última entrada nele, pelo log); antes do mês de entrada vira
-- o mês de entrada (F4); sem data no log = mês de entrada (S1, convenção E7 do site; no fluxo fica mes_evento NULL).
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

-- R12: 1ª entrada em Aguardando Feedback (1ª entrega ao cliente), pelo log
aguardando_feedback AS (
  SELECT projeto_id, MIN(DATE(alterado_em)) AS dia
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE campo_alterado = 'Status' AND valor_depois = 'Aguardando Feedback'
  GROUP BY projeto_id
),

-- F3: última entrada de cada projeto em cada status; ligada ao status atual = dia em que chegou ao status final
ultima_entrada_status AS (
  SELECT projeto_id, valor_depois AS status, MAX(DATE(alterado_em)) AS dia
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE campo_alterado = 'Status'
  GROUP BY projeto_id, valor_depois
),

itens AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
       DATE(i.criado_em)) AS criado,
    i.data_de_saida, af.dia AS aguardando, i.status, ue.dia AS status_desde
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  LEFT JOIN aguardando_feedback af USING (projeto_id)
  LEFT JOIN ultima_entrada_status ue ON ue.projeto_id = i.projeto_id AND ue.status = i.status
  WHERE i.state = 'active'                                                   -- R5
),

cards AS (
  SELECT
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(c.criado,
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(c.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(c.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    -- R12–R14: saída válida = Aguardando Feedback pelo log; sem ela, a data_de_saida; antes da entrada não vale
    CASE
      WHEN c.aguardando >= c.criado OR (c.aguardando IS NOT NULL AND c.criado IS NULL) THEN c.aguardando
      WHEN c.data_de_saida >= c.criado OR c.criado IS NULL THEN c.data_de_saida
    END AS saida,
    c.status, c.status_desde
  FROM itens c
  CROSS JOIN feriados f
)

SELECT
  -- F4 + E7: mês do evento nunca antes do mês de entrada; sem data no log = mês de entrada
  COALESCE(GREATEST(DATE_TRUNC(c.status_desde, MONTH), DATE_TRUNC(c.dia, MONTH)), DATE_TRUNC(c.dia, MONTH)) AS mes,
  c.status,
  COUNT(*) AS n,
  COUNTIF(c.status_desde IS NULL) AS sem_data,
  CURRENT_TIMESTAMP() AS _processado_em
FROM cards c
CROSS JOIN parametros pr
WHERE c.dia BETWEEN pr.inicio AND pr.fim                                     -- R4: safra do ano até a véspera da carga
  -- R16–R19: sem saída válida até ontem e com status final = não seguiu (saiu sem entrega)
  AND NOT IFNULL(c.saida <= pr.fim, FALSE)
  AND (STARTS_WITH(c.status, 'Declinado') OR c.status IN ('Standby', 'Encerrado'))
GROUP BY mes, c.status

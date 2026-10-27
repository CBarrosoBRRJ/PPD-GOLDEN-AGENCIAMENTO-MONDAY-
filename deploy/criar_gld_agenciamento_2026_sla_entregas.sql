-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_2026_sla_entregas.sql e sql/esquemas/gld_agenciamento_2026_sla_entregas.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas`
(
  projeto_id OPTIONS(description="Orçamento entregue (chave): tem passo com o cliente depois do passo 1"),
  mes OPTIONS(description="1º dia do mês da 1ª entrega (1ª entrada em Aguardando Feedback): o mês do SLA"),
  mes_entrada OPTIONS(description="1º dia do mês em que o orçamento entrou (passo 1)"),
  inicio OPTIONS(description="Entrada do passo 1 (o pedido)"),
  entregue_em OPTIONS(description="Entrada do 1º passo com o cliente (a 1ª entrega)"),
  exclusivo OPTIONS(description="Exclusividade do talento no passo 1 (Todos / Exclusivos / Não exclusivos do SLA)"),
  tipo_de_input OPTIONS(description="Tipo de input no passo 1"),
  pacote OPTIONS(description="Card de pacote/lote (nome começa por [Pacote); fica na base, só identificado"),
  h_trabalho OPTIONS(description="Horas de trabalho da equipe até a 1ª entrega, sem almoço: passos da fase equipe antes da entrega, sem o Retorno Marca"),
  h_fila OPTIONS(description="Parte de h_trabalho no status Entrada (espera na fila)"),
  h_elaboracao OPTIONS(description="Parte de h_trabalho nos status que começam por Em elaboração"),
  h_revisao OPTIONS(description="Parte de h_trabalho nos status que começam por Em revisão"),
  h_calendario OPTIONS(description="Horas corridas de calendário entre o pedido e a 1ª entrega"),
  dias_uteis OPTIONS(description="Dias úteis inteiros que o cliente esperou (pedido depois das 19h ou fora de dia útil conta do próximo dia útil)"),
  dias_uteis_fr OPTIONS(description="Dias úteis com fração: todas as horas sem almoço entre o pedido e a 1ª entrega ÷ 8 h"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_2026_sla_movimentos que a view lê")
)
OPTIONS(
  description="Um orçamento entregue por linha (view sobre a gld_agenciamento_2026_sla_movimentos): mês da 1ª entrega e o tempo até ela, em horas de trabalho da equipe sem almoço (total, fila, elaboração, revisão), horas de calendário e dias úteis inteiros e com fração. Base do SLA de entrega do site. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_2026_sla_entregas.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "sla-entregas")]
)
AS
-- gold_monday.gld_agenciamento_2026_sla_entregas (VIEW) — um orçamento entregue por linha: mês da 1ª entrega e o
-- tempo até ela (horas de trabalho da equipe sem almoço, por etapa, de calendário e dias úteis). Ficha:
-- docs/tabelas/gld_agenciamento_2026_sla_entregas.md. Base: gld_agenciamento_2026_sla_movimentos (as horas sem almoço
-- da R24). Reproduz entregas() de app/apresentacoes/gestao_orcamentos/sla/calculos.py do site (C1–C4, C9, C10, C14,
-- X6, J1), que deixa de recalcular o expediente. View: sempre igual à base, não entra no job.
WITH m AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

-- calendário sem expediente: o mesmo da R14 da gld_agenciamento_2026_sla_movimentos (copiado igual; serve aos dias úteis
-- inteiros da E5; as horas já vêm prontas da coluna sla_sem_almoco_horas, R24)
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

-- E1 (C4): 1ª entrega = 1º passo com o cliente (Aguardando Feedback); no passo 1 não é entrega (fica fora)
primeira AS (
  SELECT projeto_id, MIN(passo) AS passo_pronto FROM m WHERE fase = 'cliente' GROUP BY projeto_id
),

pronto AS (
  SELECT p.projeto_id, p.passo_pronto, x.entrada AS entregue_em
  FROM primeira p
  JOIN m x ON x.projeto_id = p.projeto_id AND x.passo = p.passo_pronto
  WHERE p.passo_pronto > 1
),

-- E2 (C2, C9, C14): horas sem almoço dos passos antes da 1ª entrega. Trabalho = fase equipe, sem o Retorno Marca
-- (espera da marca); fila = status Entrada; elaboração e revisão pelo começo do nome. E4: dias úteis com fração =
-- todas as horas sem almoço até a entrega (todas as fases) ÷ 8 h do dia útil
horas AS (
  SELECT
    x.projeto_id,
    SUM(IF(x.equipe, x.h, 0)) AS h_trabalho,
    SUM(IF(x.equipe AND x.status = 'Entrada', x.h, 0)) AS h_fila,
    SUM(IF(x.equipe AND STARTS_WITH(LOWER(x.status), 'em elabora'), x.h, 0)) AS h_elaboracao,
    SUM(IF(x.equipe AND STARTS_WITH(LOWER(x.status), 'em revis'), x.h, 0)) AS h_revisao,
    SUM(x.h) / 8 AS dias_uteis_fr
  FROM (
    SELECT m.projeto_id, m.status, IFNULL(m.sla_sem_almoco_horas, 0) AS h,
      m.fase = 'equipe' AND NOT IFNULL(STARTS_WITH(LOWER(m.status), 'em elaboração - retorno marca'), FALSE) AS equipe
    FROM m JOIN pronto p ON p.projeto_id = m.projeto_id AND m.passo < p.passo_pronto) x
  GROUP BY x.projeto_id
),

base AS (
  SELECT
    p.projeto_id, a.entrada AS inicio, p.entregue_em, a.exclusivo, a.tipo_de_input, a.nome_projeto,
    -- E5 (C3b): dias úteis inteiros que o cliente esperou; pedido depois das 19h ou fora de dia útil conta do próximo
    IF(EXTRACT(HOUR FROM a.entrada) >= 19 OR EXTRACT(DAYOFWEEK FROM a.entrada) IN (1, 7)
         OR DATE(a.entrada) IN UNNEST(f.dias),
       (SELECT MIN(d) FROM UNNEST(GENERATE_DATE_ARRAY(DATE_ADD(DATE(a.entrada), INTERVAL 1 DAY),
                                                      DATE_ADD(DATE(a.entrada), INTERVAL 30 DAY))) AS d
        WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias)),
       DATE(a.entrada)) AS conta_de,
    f.dias
  FROM pronto p
  JOIN m a ON a.projeto_id = p.projeto_id AND a.passo = 1
  CROSS JOIN feriados f
)

SELECT
  b.projeto_id,
  DATE_TRUNC(DATE(b.entregue_em), MONTH) AS mes,                    -- E1 (C4): mês da 1ª entrega
  DATE_TRUNC(DATE(b.inicio), MONTH) AS mes_entrada,
  b.inicio,
  b.entregue_em,
  b.exclusivo,                                                      -- C10: do passo 1
  b.tipo_de_input,                                                  -- J1: do passo 1
  STARTS_WITH(TRIM(IFNULL(b.nome_projeto, '')), '[Pacote') AS pacote,  -- X6: card de pacote, só identificado
  h.h_trabalho,
  h.h_fila,
  h.h_elaboracao,
  h.h_revisao,
  DATETIME_DIFF(b.entregue_em, b.inicio, MICROSECOND) / 3600000000 AS h_calendario,  -- E3 (C3)
  (SELECT COUNT(*) FROM UNNEST(GENERATE_DATE_ARRAY(b.conta_de, DATE_SUB(DATE(b.entregue_em), INTERVAL 1 DAY))) AS d
   WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(b.dias)) AS dias_uteis,
  h.dias_uteis_fr,
  (SELECT MAX(_processado_em) FROM m) AS _processado_em
FROM base b
JOIN horas h USING (projeto_id)
;

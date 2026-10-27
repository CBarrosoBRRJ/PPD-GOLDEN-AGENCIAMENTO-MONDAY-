-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_atendimento_mensal.sql e sql/esquemas/gld_agenciamento_atendimento_mensal.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_atendimento_mensal`
(
  mes OPTIONS(description="1º dia do mês, de 2025-01 até o mês de ontem (chave)"),
  completo OPTIONS(description="TRUE = mês fechado; FALSE = mês de ontem, parcial"),
  entradas OPTIONS(description="Pedidos que entraram no mês (quantidade + quantidade_estimada da diária)"),
  entregues OPTIONS(description="Entregues ao cliente no mês, só pedidos do próprio ano"),
  sem_entrega OPTIONS(description="Saíram sem entrega no mês, só pedidos do próprio ano; sem data, no mês de entrada"),
  sem_entrega_sem_data OPTIONS(description="Dos sem_entrega, quantos sem data (atribuídos ao mês de entrada)"),
  respondidos OPTIONS(description="entregues + sem_entrega"),
  veio OPTIONS(description="Fila que veio do mês anterior (0 em janeiro)"),
  para_atender OPTIONS(description="veio + entradas"),
  ficou OPTIONS(description="Fila no fim do mês = para_atender − respondidos"),
  status_confere OPTIONS(description="A composição por status (gld_agenciamento_2026_saidas_status) soma igual a sem_entrega no mês"),
  externos OPTIONS(description="Saídas por decisão de fora da equipe (Declinado pelo Mercado, Declinado pelo talento, Encerrado); 0 quando o status não confere"),
  dependia OPTIONS(description="Demanda que dependia da equipe = para_atender − externos (denominador do % de entrega, A27)"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_fluxo_mensal que a view lê")
)
OPTIONS(
  description="O mês do Atendimento (view sobre a gld_agenciamento_entrada_diaria, a gld_agenciamento_fluxo_mensal e a gld_agenciamento_2026_saidas_status): entradas, entregues e saídas sem entrega dos pedidos do ano, fila que veio e que ficou, para atender, saídas externas e a demanda que dependia da equipe. Sempre igual às bases. Regras: docs/tabelas/gld_agenciamento_atendimento_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2024-2026"), ("origem", "monday"), ("tipo", "atendimento-mensal")]
)
AS
-- gold_monday.gld_agenciamento_atendimento_mensal (VIEW) — o mês do Atendimento: entradas, entregues e saídas sem
-- entrega dos pedidos do ano, fila (o que veio do mês anterior e o que ficou), para atender, saídas externas (A27) e a
-- demanda que dependia da equipe. Ficha: docs/tabelas/gld_agenciamento_atendimento_mensal.md. Bases:
-- gld_agenciamento_entrada_diaria (entradas), gld_agenciamento_fluxo_mensal (saídas, só safras do ano) e
-- gld_agenciamento_2026_saidas_status (externos). Reproduz atendimento(), status_sem_entrega() e analise_ritmo() de
-- app/apresentacoes/gestao_orcamentos/atendimento/calculos.py do site. Os percentuais ficam com quem lê. View.
-- AM1: a fila recomeça em janeiro (só pedidos do próprio ano, D29); AM2: saída sem entrega sem data = mês de entrada
-- (E7); AM3: externos = Declinado pelo Mercado, Declinado pelo talento e Encerrado, só no mês em que a composição por
-- status confere com as saídas sem entrega do fluxo (A26/A27); senão 0.
WITH ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

meses AS (
  SELECT mes FROM ontem, UNNEST(GENERATE_DATE_ARRAY(DATE '2025-01-01', DATE_TRUNC(dia, MONTH), INTERVAL 1 MONTH)) AS mes
),

entradas AS (
  SELECT DATE_TRUNC(e.data, MONTH) AS mes, SUM(e.quantidade + e.quantidade_estimada) AS n
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria` e, ontem o
  WHERE e.data <= o.dia
  GROUP BY mes
),

saidas AS (
  SELECT
    COALESCE(mes_evento, mes_entrada) AS mes,                                   -- AM2
    SUM(IF(evento = 'entregue', quantidade, 0)) AS entregues,
    SUM(IF(evento = 'nao_seguiu', quantidade, 0)) AS sem_entrega,
    SUM(IF(evento = 'nao_seguiu' AND mes_evento IS NULL, quantidade, 0)) AS sem_data
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
  WHERE evento IN ('entregue', 'nao_seguiu')
    AND EXTRACT(YEAR FROM mes_entrada) = EXTRACT(YEAR FROM COALESCE(mes_evento, mes_entrada))  -- AM1
  GROUP BY mes
),

status AS (
  SELECT mes, SUM(n) AS total,
    SUM(IF(status IN ('Declinado pelo Mercado', 'Declinado pelo talento', 'Encerrado'), n, 0)) AS externos
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status`
  GROUP BY mes
),

base AS (
  SELECT
    x.mes,
    IFNULL(e.n, 0) AS entradas,
    IFNULL(s.entregues, 0) AS entregues,
    IFNULL(s.sem_entrega, 0) AS sem_entrega,
    IFNULL(s.sem_data, 0) AS sem_entrega_sem_data,
    IFNULL(s.entregues, 0) + IFNULL(s.sem_entrega, 0) AS respondidos,
    st.total = IFNULL(s.sem_entrega, 0) AS status_confere,                     -- AM3
    IF(st.total = IFNULL(s.sem_entrega, 0), st.externos, 0) AS externos,
    LAST_DAY(x.mes) <= o.dia AS completo
  FROM meses x
  CROSS JOIN ontem o
  LEFT JOIN entradas e USING (mes)
  LEFT JOIN saidas s USING (mes)
  LEFT JOIN status st USING (mes)
),

fila AS (
  SELECT *,
    SUM(entradas - respondidos) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes) AS ficou   -- AM1
  FROM base
)

SELECT
  mes,
  completo,
  entradas,
  entregues,
  sem_entrega,
  sem_entrega_sem_data,
  respondidos,
  IFNULL(LAG(ficou) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes), 0) AS veio,
  IFNULL(LAG(ficou) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes), 0) + entradas AS para_atender,
  ficou,
  IFNULL(status_confere, FALSE) AS status_confere,
  IFNULL(externos, 0) AS externos,
  IFNULL(LAG(ficou) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes), 0) + entradas - IFNULL(externos, 0)
    AS dependia,
  (SELECT MAX(_processado_em) FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`)
    AS _processado_em
FROM fila
;

-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_fila_mensal.sql e sql/esquemas/gld_agenciamento_fila_mensal.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fila_mensal`
(
  mes OPTIONS(description="1º dia do mês do extrato, de 2024-10 até o mês de ontem. Com mes_entrada, forma a chave"),
  mes_entrada OPTIONS(description="Safra: 1º dia do mês de entrada dos pedidos"),
  do_ano OPTIONS(description="TRUE = safra do mesmo ano do mês (entra na fila); FALSE = safra de ano anterior, só com as entregas do mês"),
  novos OPTIONS(description="Pedidos que entraram no próprio mês (safra = mês)"),
  represados OPTIONS(description="Pedidos de safras anteriores do ano ainda abertos no 1º dia do mês"),
  entregues OPTIONS(description="Entregues ao cliente no mês (1ª entrega)"),
  nao_seguiram OPTIONS(description="Saíram sem entrega no mês; sem data, no mês de entrada"),
  seguem OPTIONS(description="Ainda abertos no fim do mês (no mês de ontem, até ontem)"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_fluxo_mensal que a view lê")
)
OPTIONS(
  description="Extrato de fila por mês e mês de entrada (view sobre a gld_agenciamento_fluxo_mensal): represados e novos no início, entregues e saídas sem entrega no mês, e o que segue aberto no fim; só pedidos do próprio ano, mais as entregas do mês de safras de anos anteriores. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_fila_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2024-2026"), ("origem", "monday"), ("tipo", "fila-mensal")]
)
AS
-- gold_monday.gld_agenciamento_fila_mensal (VIEW) — o mês como um extrato de fila, por mês de entrada (safra): quanto
-- estava aberto no início do mês (represados e novos), quanto foi entregue e quanto saiu sem entrega no mês, e quanto
-- seguiu aberto no fim. Ficha: docs/tabelas/gld_agenciamento_fila_mensal.md. Base: gld_agenciamento_fluxo_mensal.
-- Reproduz extrato() de app/apresentacoes/gestao_orcamentos/entrada/calculos.py do site (E7, Início). View: sempre
-- igual à base, não entra no job.
-- FM1: a fila só conta pedidos do próprio ano do mês (decisão do Caio, 23/10/2026); das safras de anos anteriores fica
-- só o que foi entregue no mês (do_ano = FALSE), para a dica de entregas do mês.
-- FM2: "não seguiu" sem data (boards 2024/2025 e card sem log) conta no mês de entrada e não fica represado.
WITH f AS (
  SELECT mes_entrada AS safra, evento, mes_evento AS quando, quantidade AS n, _processado_em
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
),

-- meses de 2024-10 (início da gold) até o mês de ontem (véspera da carga, em São Paulo)
meses AS (
  SELECT mes
  FROM (SELECT DATE_TRUNC(DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY), MONTH) AS ultimo
        FROM f),
    UNNEST(GENERATE_DATE_ARRAY(DATE '2024-10-01', ultimo, INTERVAL 1 MONTH)) AS mes
),

linhas AS (
  SELECT
    x.mes,
    f.safra,
    EXTRACT(YEAR FROM f.safra) = EXTRACT(YEAR FROM x.mes) AS do_ano,
    SUM(IF(f.safra = x.mes, f.n, 0)) AS novos,
    SUM(IF(f.safra < x.mes AND (f.evento = 'em_andamento' OR f.quando >= x.mes), f.n, 0)) AS represados,
    SUM(IF(f.evento = 'entregue' AND f.quando = x.mes, f.n, 0)) AS entregues,
    SUM(IF(f.evento = 'nao_seguiu' AND (f.quando = x.mes OR f.quando IS NULL AND f.safra = x.mes), f.n, 0))
      AS nao_seguiram,
    SUM(IF(f.evento = 'em_andamento' OR f.quando > x.mes, f.n, 0)) AS seguem
  FROM meses x
  JOIN f ON f.safra <= x.mes
  GROUP BY x.mes, f.safra, do_ano
)

SELECT
  mes,
  safra AS mes_entrada,
  do_ano,
  IF(do_ano, novos, 0) AS novos,
  IF(do_ano, represados, 0) AS represados,
  entregues,
  IF(do_ano, nao_seguiram, 0) AS nao_seguiram,
  IF(do_ano, seguem, 0) AS seguem,
  (SELECT MAX(_processado_em) FROM f) AS _processado_em
FROM linhas
WHERE IF(do_ano, novos + represados + entregues + nao_seguiram + seguem, entregues) > 0
;

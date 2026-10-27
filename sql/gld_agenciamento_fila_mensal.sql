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

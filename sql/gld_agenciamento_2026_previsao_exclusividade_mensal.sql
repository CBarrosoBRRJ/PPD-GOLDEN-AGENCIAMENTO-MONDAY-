-- gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal — pedidos do ano por mês e tipo de input (Inbound, Mercado), divididos em
-- exclusivos, não exclusivos e sem talento (view, sem cálculo próprio: soma por mês da gld_agenciamento_2026_previsao_exclusividade_diaria).
-- Ficha: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md, seção "Derivações". Mês como DATE (1º dia). completo = o mês terminou até o último dia
-- da base (ontem, na carga do dia): é o mês de ontem que fica FALSE, ainda parcial.
SELECT
  DATE_TRUNC(data, MONTH) AS mes,
  tipo,
  SUM(exclusivos) AS exclusivos,
  SUM(nao_exclusivos) AS nao_exclusivos,
  SUM(sem_talento) AS sem_talento,
  SUM(total) AS total,
  LAST_DAY(MIN(data)) <= ANY_VALUE(ultimo_dia) AS completo,
  MAX(_processado_em) AS _processado_em
FROM (SELECT *, MAX(data) OVER () AS ultimo_dia FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`)
GROUP BY mes, tipo

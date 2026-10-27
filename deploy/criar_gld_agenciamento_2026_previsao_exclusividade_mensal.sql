-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_2026_previsao_exclusividade_mensal.sql e sql/esquemas/gld_agenciamento_2026_previsao_exclusividade_mensal.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal`
(
  mes OPTIONS(description="1º dia do mês de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), de janeiro até o mês de ontem. Com tipo, forma a chave"),
  tipo OPTIONS(description="Tipo de input da silver: Inbound ou Mercado (as séries da previsão de demanda)"),
  exclusivos OPTIONS(description="Pedidos com talento exclusivo na data do pedido"),
  nao_exclusivos OPTIONS(description="Pedidos com talento não exclusivo na data do pedido (inclui Squad de Talentos)"),
  sem_talento OPTIONS(description="Pedidos sem exclusividade definida na silver (sem talento)"),
  total OPTIONS(description="exclusivos + nao_exclusivos + sem_talento; igual às entradas do mês e tipo na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  completo OPTIONS(description="TRUE = mês fechado; FALSE = mês de ontem (último dia da base), ainda parcial (não comparar com mês fechado)"),
  _processado_em OPTIONS(description="Momento da execução da tabela base (gld_agenciamento_2026_previsao_exclusividade_diaria)")
)
OPTIONS(
  description="Pedidos do board 2026 por mês de entrada e tipo de input (Inbound, Mercado), divididos em exclusivos, não exclusivos e sem talento (view, sem cálculo próprio: soma por mês da gld_agenciamento_2026_previsao_exclusividade_diaria); completo separa os meses fechados do mês de ontem, ainda parcial. Uma linha por mês × tipo. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "previsao-exclusividade-mensal")]
)
AS
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
;

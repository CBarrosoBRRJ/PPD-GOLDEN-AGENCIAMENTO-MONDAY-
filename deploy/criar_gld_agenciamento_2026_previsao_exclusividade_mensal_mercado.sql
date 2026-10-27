-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_2026_previsao_exclusividade_mensal_mercado.sql e sql/esquemas/gld_agenciamento_2026_previsao_exclusividade_mensal_mercado.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_mercado`
(
  mes OPTIONS(description="1º dia do mês de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), de janeiro até o mês de ontem; só Mercado. É a chave"),
  exclusivos OPTIONS(description="Pedidos com talento exclusivo na data do pedido"),
  nao_exclusivos OPTIONS(description="Pedidos com talento não exclusivo na data do pedido (inclui Squad de Talentos)"),
  sem_talento OPTIONS(description="Pedidos sem exclusividade definida na silver (sem talento)"),
  total OPTIONS(description="exclusivos + nao_exclusivos + sem_talento; igual às entradas de Mercado do mês na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  completo OPTIONS(description="TRUE = mês fechado; FALSE = mês de ontem, ainda parcial (não comparar com mês fechado)"),
  _processado_em OPTIONS(description="Momento da execução")
)
OPTIONS(
  description="Só Mercado da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio): pedidos do board 2026 por mês de entrada, divididos em exclusivos, não exclusivos e sem talento, de janeiro até ontem; completo separa os meses fechados do mês corrente. Uma linha por mês. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "previsao-exclusividade-mensal-mercado")]
)
AS
-- gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_mercado — só Mercado da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio).
-- Ficha: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md, seção "Derivações". Mesmas colunas da base, sem tipo (é sempre Mercado).
SELECT mes, exclusivos, nao_exclusivos, sem_talento, total, completo, _processado_em
FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal`
WHERE tipo = 'Mercado'
;

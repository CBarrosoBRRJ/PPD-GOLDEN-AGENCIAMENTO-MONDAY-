-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_2026_sla_entregas_status.sql e sql/esquemas/gld_agenciamento_2026_sla_entregas_status.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US), depois de criar a
-- tabela base. Recria só a view (CREATE OR REPLACE VIEW): seguro repetir; não guarda dados nem mexe na base.

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas_status`
(
  projeto_id OPTIONS(description="Orçamento entregue (o mesmo da gld_agenciamento_2026_sla_entregas). Com status, forma a chave"),
  status OPTIONS(description="Status da fase equipe antes da 1ª entrega (sem o Retorno Marca)"),
  h OPTIONS(description="Horas sem almoço no status (passagens repetidas somadas); por orçamento, a soma é o h_trabalho"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_2026_sla_movimentos que a view lê")
)
OPTIONS(
  description="Horas de trabalho sem almoço de cada orçamento entregue em cada status da equipe antes da 1ª entrega (view sobre a gld_agenciamento_2026_sla_movimentos); por orçamento, soma o h_trabalho da gld_agenciamento_2026_sla_entregas. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_2026_sla_entregas.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "sla-entregas-status")]
)
AS
-- gold_monday.gld_agenciamento_2026_sla_entregas_status (VIEW) — horas de trabalho da equipe (sem almoço) de cada
-- orçamento entregue em cada status, antes da 1ª entrega. Por orçamento, a soma é o h_trabalho da
-- gld_agenciamento_2026_sla_entregas. Ficha: docs/tabelas/gld_agenciamento_2026_sla_entregas.md. Reproduz
-- horas_por_status() (K1) de sla/calculos.py do site (slide 6 do estudo "Como medimos"). View: sempre igual à base.
WITH m AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

-- E1: 1ª entrega = 1º passo com o cliente; no passo 1 não é entrega
pronto AS (
  SELECT projeto_id, MIN(passo) AS passo_pronto
  FROM m WHERE fase = 'cliente'
  GROUP BY projeto_id
  HAVING MIN(passo) > 1
)

-- E2: fase equipe, antes da 1ª entrega, sem o Retorno Marca; passagens repetidas no mesmo status somadas
SELECT
  m.projeto_id,
  m.status,
  SUM(m.sla_sem_almoco_horas) AS h,
  (SELECT MAX(_processado_em) FROM m) AS _processado_em
FROM m
JOIN pronto p ON p.projeto_id = m.projeto_id AND m.passo < p.passo_pronto
WHERE m.fase = 'equipe' AND NOT IFNULL(STARTS_WITH(LOWER(m.status), 'em elaboração - retorno marca'), FALSE)
GROUP BY m.projeto_id, m.status
;

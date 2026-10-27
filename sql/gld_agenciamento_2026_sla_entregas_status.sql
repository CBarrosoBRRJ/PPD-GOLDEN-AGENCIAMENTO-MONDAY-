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

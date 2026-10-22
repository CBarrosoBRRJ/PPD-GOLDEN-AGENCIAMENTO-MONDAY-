-- RASCUNHO (variação futura, não aprovada): gold_monday.gld_agenciamento_2026_sla_projetos
-- Uma linha por projeto com os totais de SLA da equipe, do cliente e do Standby (R16).
-- Lê a gold_monday.gld_agenciamento_2026_sla_movimentos. Não faz parte da entrega atual.

WITH historico AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

projetos AS (
  SELECT
    projeto_id,
    item_id_atual,
    item_id_legado,
    board_id,
    nome_projeto,
    link_projeto,
    status,
    talento,
    exclusivo,
    tipo_de_input,
    tipo_de_output,
    marca,
    orcamento AS orcamento_email
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens`
  -- o recorte (R1–R4, R11, R12) é o do histórico
  WHERE projeto_id IN (SELECT projeto_id FROM historico)
),

-- R5: nome de cada pessoa pelo e-mail, o mais recente no log
pessoas AS (
  SELECT
    LOWER(alterado_por_email) AS email,
    ARRAY_AGG(alterado_por_nome ORDER BY alterado_em DESC LIMIT 1)[OFFSET(0)] AS nome
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE alterado_por_email IS NOT NULL AND alterado_por_nome IS NOT NULL
  GROUP BY email
),

orcamento AS (
  SELECT
    p.projeto_id,
    -- mantém a ordem da célula; e-mail sem nome conhecido aparece como o próprio e-mail
    STRING_AGG(COALESCE(pe.nome, e.email), ', ' ORDER BY e.pos) AS orcamento
  FROM projetos p,
    UNNEST(SPLIT(p.orcamento_email, ',')) AS email_bruto WITH OFFSET AS pos
  CROSS JOIN UNNEST([STRUCT(TRIM(LOWER(email_bruto)) AS email, pos AS pos)]) AS e
  LEFT JOIN pessoas pe ON pe.email = e.email
  GROUP BY p.projeto_id
),

-- R16: SLA do projeto = soma das passagens de cada fase
--   equipe: Entrada até entrar em Aguardando Feedback; cada volta para a equipe volta a contar
--   cliente: entrada em Aguardando Feedback até o fechamento (ou a volta para a equipe)
--   standby: tempo em Standby, à parte (não conta para a equipe nem para o cliente)
totais AS (
  SELECT
    projeto_id,
    MIN(entrada) AS entrada_em,
    MIN(IF(fase = 'cliente', entrada, NULL)) AS primeiro_aguardando_em,
    MAX(IF(fase = 'fechamento' AND saida IS NULL, entrada, NULL)) AS fechamento_em,
    ROUND(SUM(IF(fase = 'equipe', sla_corrido_horas, 0)), 2) AS sla_equipe_corrido_horas,
    ROUND(SUM(IF(fase = 'equipe', sla_util_horas, 0)), 2) AS sla_equipe_util_horas,
    ROUND(SUM(IF(fase = 'cliente', sla_corrido_horas, NULL)), 2) AS sla_cliente_corrido_horas,
    ROUND(SUM(IF(fase = 'cliente', sla_util_horas, NULL)), 2) AS sla_cliente_util_horas,
    ROUND(SUM(IF(fase = 'standby', sla_corrido_horas, NULL)), 2) AS sla_standby_corrido_horas,
    ROUND(SUM(IF(fase = 'standby', sla_util_horas, NULL)), 2) AS sla_standby_util_horas,
    LOGICAL_OR(fase = 'cliente' AND saida IS NULL) AS cliente_em_aberto,
    COUNTIF(volta) AS voltas_para_equipe,
    COUNT(*) AS passos
  FROM (
    -- volta = o projeto retorna à equipe depois de já ter ido ao cliente ou a um fechamento (Standby no meio não muda)
    SELECT *,
      fase = 'equipe'
        AND LAG(fase) OVER (PARTITION BY projeto_id ORDER BY passo) != 'equipe'
        AND COALESCE(LOGICAL_OR(fase IN ('cliente', 'fechamento')) OVER (
              PARTITION BY projeto_id ORDER BY passo ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), FALSE) AS volta
    FROM historico)
  GROUP BY projeto_id
)

SELECT
  p.projeto_id,
  p.item_id_atual,
  p.item_id_legado,
  p.board_id,
  p.nome_projeto,
  p.status,
  p.talento,
  p.exclusivo,
  p.tipo_de_input,
  p.tipo_de_output,
  p.marca,
  o.orcamento,
  t.entrada_em,
  t.primeiro_aguardando_em,
  t.fechamento_em,
  t.sla_equipe_corrido_horas,
  t.sla_equipe_util_horas,
  t.sla_cliente_corrido_horas,
  t.sla_cliente_util_horas,
  t.sla_standby_corrido_horas,
  t.sla_standby_util_horas,
  t.cliente_em_aberto,
  t.voltas_para_equipe,
  t.passos,
  p.link_projeto
FROM projetos p
JOIN totais t USING (projeto_id)
LEFT JOIN orcamento o USING (projeto_id)

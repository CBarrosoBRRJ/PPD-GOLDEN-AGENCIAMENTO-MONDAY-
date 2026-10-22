-- GERADO por tools/gerar_deploy.py a partir de sql/gld_agenciamento_2026_sla_movimentos.sql e sql/esquemas/gld_agenciamento_2026_sla_movimentos.csv.
-- Não editar à mão: altere o SELECT ou o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Recria a tabela inteira (CREATE OR REPLACE): seguro repetir; não apaga nada fora desta tabela.

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
(
  projeto_id STRING OPTIONS(description="Chave do projeto do início ao fim (igual à silver; atravessa a migração de 03/09/2026). Com passo, forma a chave da tabela"),
  item_id_atual STRING OPTIONS(description="ID do item no board atual do monday"),
  item_id_legado STRING OPTIONS(description="ID do item no board antigo (conta viu2); vazio nos projetos criados depois da migração"),
  board_id STRING OPTIONS(description="ID do board no monday"),
  nome_projeto STRING OPTIONS(description="Nome do projeto, como na silver"),
  status_atual STRING OPTIONS(description="Status do projeto hoje (foto do dia); serve para filtrar, ex.: só encerrados"),
  talento STRING OPTIONS(description="Talento do projeto (silver): um nome, Squad de Talentos (mais de um) ou vazio"),
  exclusivo BOOL OPTIONS(description="O talento era exclusivo na data do projeto (silver); vazio sem talento"),
  tipo_de_input STRING OPTIONS(description="Tipo de input (forma oficial da silver)"),
  tipo_de_output STRING OPTIONS(description="Tipo de output (forma oficial da silver)"),
  marca STRING OPTIONS(description="Marca do projeto (Catálogo de Marcas, pela silver)"),
  orcamento STRING OPTIONS(description="Nome da pessoa da equipe de orçamento (R5); mais de uma = nomes separados por vírgula, na ordem do monday. É o responsável de hoje, não o da época de cada passo"),
  passo INT64 OPTIONS(description="Ordem da passagem do projeto pelos status (1 = Entrada)"),
  status STRING OPTIONS(description="Status desta passagem (como no log; nomes antigos mantidos)"),
  fase STRING OPTIONS(description="Relógio do SLA (R15): equipe (Entrada, elaboração, revisão e status novos), cliente (Aguardando Feedback), standby (Standby, relógio próprio) ou fechamento (Encerrado, Negócio Fechado, Declinado, Sem retorno)"),
  entrada DATETIME OPTIONS(description="Quando o projeto chegou neste status (horário de Brasília)"),
  saida DATETIME OPTIONS(description="Quando o projeto mudou para o status seguinte (horário de Brasília); vazio = status atual"),
  saida_horario STRING OPTIONS(description="Horário da mudança que encerrou o passo (R21): expediente, antes do expediente, depois do expediente ou fim de semana ou feriado"),
  saida_por STRING OPTIONS(description="Quem fez a mudança que encerrou o passo (nome no monday; a automação aparece como Automação do monday)"),
  saida_por_automacao BOOL OPTIONS(description="A mudança que encerrou o passo foi feita por uma automação (ex.: Encerrado automático 30 dias depois de Aguardando Feedback)"),
  sla_corrido_horas FLOAT64 OPTIONS(description="Tempo no status em horas corridas (saída − entrada; R13); vazio enquanto o status não termina"),
  sla_util_horas FLOAT64 OPTIONS(description="Tempo no status em horas úteis (R13): só seg–sex, 10h–19h, fora de feriados e dias sem expediente (R14); vazio enquanto o status não termina"),
  fora_expediente BOOL OPTIONS(description="A mudança que encerrou o passo foi feita por uma pessoa fora do horário (R20); a automação não conta"),
  hora_extra_horas FLOAT64 OPTIONS(description="Hora extra estimada (R20): depois do expediente = das 19h (ou da entrada) até a mudança; antes do expediente ou fim de semana/feriado = da entrada até a mudança, só no mesmo dia; vazio quando não se aplica ou não dá para estimar"),
  sla_corrido STRING OPTIONS(description="Leitura do tempo corrido: Xd HHhMM (1 dia = 24 h)"),
  sla_util STRING OPTIONS(description="Leitura do tempo útil: Xd HHhMM (1 dia útil = 9 h)"),
  em_aberto BOOL OPTIONS(description="Status atual ainda em andamento (fase equipe, cliente ou standby; R17)"),
  aberto_ha_corrido_horas FLOAT64 OPTIONS(description="Há quanto tempo o status atual está aberto, em horas corridas, até a execução (_processado_em); muda a cada execução"),
  aberto_ha_util_horas FLOAT64 OPTIONS(description="Há quanto tempo o status atual está aberto, em horas úteis, até a execução; muda a cada execução"),
  alerta BOOL OPTIONS(description="Cliente sem retorno: em Aguardando Feedback, em aberto, há mais de 10 dias úteis (R18; limite provisório)"),
  retrabalho BOOL OPTIONS(description="Voltou de Aguardando Feedback para um status da equipe (R19)"),
  reaberto BOOL OPTIONS(description="Saiu de um fechamento (Encerrado, Declinado) e voltou a andar (R19)"),
  entrega_sem_aguardando BOOL OPTIONS(description="Fechou vindo da equipe sem registrar a nova entrega em Aguardando Feedback, depois de já ter ido ao cliente (R19); Declinado não conta"),
  encerrado_sem_entrega BOOL OPTIONS(description="Fechou vindo da equipe sem nunca ter ido ao cliente (R19); Declinado não conta"),
  link_projeto STRING OPTIONS(description="Link do projeto no monday"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução que gerou a tabela")
)
CLUSTER BY projeto_id, status_atual
OPTIONS(
  description="SLA do board Backlog 2026 | Agenciamento: uma linha por passagem de um projeto por um status (projeto_id + passo), com fase (equipe, cliente, standby, fechamento), tempo corrido e útil, tempo em aberto, alerta e marcações do fluxo. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_sla_movimentos.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "sla-movimentos")]
)
AS
-- gold_monday.gld_agenciamento_2026_sla_movimentos
-- Uma linha por passagem de um projeto por um status (chave projeto_id + passo), em ordem: atributos do projeto,
-- passo, status, fase, entrada (chegou no status), saída (mudou para o próximo), tempo no status (corrido e útil),
-- tempo em aberto, alerta e marcações do fluxo. Link do projeto no final.
-- Só leitura (SELECT). A gravação é feita pelo deploy/ (CREATE OR REPLACE TABLE ... AS este SELECT).
-- Regras R1–R22: docs/tabelas/gld_agenciamento_2026_sla_movimentos.md. Colunas: sql/esquemas/.

WITH parametros AS (
  SELECT
    CURRENT_DATETIME('America/Sao_Paulo') AS agora,  -- R17: referência do tempo em aberto (o momento da execução)
    10 AS alerta_dias_uteis_cliente,                 -- R18: limite provisório do alerta (dia útil = 9 h)
    2 AS limite_clique_minutos                       -- R22: ida e volta mais curta que isso = clique corrigido
),

projetos AS (
  SELECT
    projeto_id,
    item_id_atual,
    item_id_legado,
    board_id,
    nome_projeto,
    status AS status_atual,
    talento,
    exclusivo,
    tipo_de_input,
    tipo_de_output,
    marca,
    orcamento AS orcamento_email,
    link_projeto,
    criado_em
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens`
  WHERE
    -- R1: status atual de ciclo completo = Aguardando Feedback ou um fechamento (R15)
    (status = 'Aguardando Feedback'
     OR REGEXP_CONTAINS(LOWER(status), r'^(encerrado|neg[oó]cio fechado|declinado|sem retorno)'))
    -- R2: sem excluídos
    AND state = 'active'
    -- R23: sem data de criação não entra (o 1º passo ficaria sem entrada e sem tempo)
    AND criado_em IS NOT NULL
    -- R3: sem marcadores do nome (NULL conta como FALSE)
    AND NOT COALESCE(upfront OR curadoria OR defesa OR levop OR midia_kit OR analise, FALSE)
    -- R4: sem esses tipos de output (output vazio fica)
    AND COALESCE(tipo_de_output, '') NOT IN (
      'Levop | Card de Oportunidade | Informação por e-mail',
      'Curadoria Orçada',
      'Defesas | Estudo Comercial | Curadorias')
    -- R11 + R12: só projetos com histórico de Status que começa em Entrada
    -- (1ª mudança: Entrada -> outro, ou vazio -> Entrada)
    AND projeto_id IN (
      SELECT projeto_id FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
      WHERE campo_alterado = 'Status'
      QUALIFY ROW_NUMBER() OVER (PARTITION BY projeto_id ORDER BY alterado_em, log_id) = 1
        AND (valor_antes = 'Entrada' OR (valor_antes IS NULL AND valor_depois = 'Entrada')))
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

-- R6: só as mudanças da coluna Status, em ordem
eventos AS (
  SELECT
    l.projeto_id,
    l.alterado_em,
    l.valor_antes,
    l.valor_depois,
    l.alterado_por_nome,
    l.alterado_por_automacao,
    ROW_NUMBER() OVER (PARTITION BY l.projeto_id ORDER BY l.alterado_em, l.log_id) AS ordem
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log` l
  JOIN projetos USING (projeto_id)
  WHERE l.campo_alterado = 'Status'
),

-- R7: o primeiro status é o "antes" do primeiro evento (ou Entrada), desde a criação do projeto
inicial AS (
  SELECT
    p.projeto_id,
    -- a criação ou o 1º evento, o que vier antes (há eventos segundos antes da criação registrada)
    LEAST(p.criado_em, COALESCE(e.alterado_em, p.criado_em)) AS entrada,
    COALESCE(e.valor_antes, 'Entrada') AS status,
    0 AS ordem,
    CAST(NULL AS STRING) AS alterado_por_nome, CAST(NULL AS BOOL) AS alterado_por_automacao
  FROM projetos p
  LEFT JOIN eventos e ON e.projeto_id = p.projeto_id AND e.ordem = 1
),

-- R8: status limpo (valor_depois vazio) não conta como passagem.
-- R10: forma oficial da silver (opcoes.csv) para o status escrito de outro jeito no log — aplicada aqui, antes das
-- comparações de R9 e R22, para a grafia antiga e a oficial contarem como o mesmo status
passos AS (
  SELECT
    projeto_id, entrada,
    IF(status = 'Em Elaboração - Orçamentos', 'Em elaboração - Orçamentos', status) AS status,
    ordem, alterado_por_nome, alterado_por_automacao
  FROM (
    SELECT projeto_id, entrada, status, ordem, alterado_por_nome, alterado_por_automacao FROM inicial
    UNION ALL
    SELECT projeto_id, alterado_em, valor_depois, ordem, alterado_por_nome, alterado_por_automacao
    FROM eventos WHERE valor_depois IS NOT NULL)
),

-- R9: o mesmo status repetido em sequência vale uma passagem só (vale a primeira entrada)
sem_repeticao AS (
  SELECT * FROM (
    SELECT *, LAG(status) OVER (PARTITION BY projeto_id ORDER BY entrada, ordem) AS status_anterior
    FROM passos)
  WHERE status_anterior IS NULL OR status_anterior != status
),

-- R22: ida e volta rápida (A → B → A, com B mais curto que o limite) é um clique corrigido: B sai
sem_clique AS (
  SELECT x.* EXCEPT (prox_status, seg_no_status)
  FROM (
    SELECT
      s.*,
      LEAD(s.status) OVER w AS prox_status,
      DATETIME_DIFF(LEAD(s.entrada) OVER w, s.entrada, SECOND) AS seg_no_status
    FROM sem_repeticao s
    WINDOW w AS (PARTITION BY s.projeto_id ORDER BY s.entrada, s.ordem)) x
  CROSS JOIN parametros pr
  WHERE NOT COALESCE(x.status_anterior = x.prox_status AND x.seg_no_status < pr.limite_clique_minutos * 60, FALSE)
),

-- ... e os dois A juntam numa passagem só (R9 de novo; vale a primeira entrada)
sem_clique_repeticao AS (
  SELECT * EXCEPT (status_anterior_2)
  FROM (
    SELECT * EXCEPT (status_anterior),
      LAG(status) OVER (PARTITION BY projeto_id ORDER BY entrada, ordem) AS status_anterior_2
    FROM sem_clique)
  WHERE status_anterior_2 IS NULL OR status_anterior_2 != status
),

historico AS (
  SELECT
    projeto_id,
    ROW_NUMBER() OVER (PARTITION BY projeto_id ORDER BY entrada, ordem) AS passo,
    status,  -- já na forma oficial (R10, em passos)
    entrada,
    LEAD(entrada) OVER (PARTITION BY projeto_id ORDER BY entrada, ordem) AS saida,  -- NULL = status atual
    -- R21: quem fez a mudança que encerrou o passo (a entrada do passo seguinte)
    LEAD(alterado_por_nome) OVER (PARTITION BY projeto_id ORDER BY entrada, ordem) AS saida_por,
    LEAD(alterado_por_automacao) OVER (PARTITION BY projeto_id ORDER BY entrada, ordem) AS saida_por_automacao
  FROM sem_clique_repeticao
),

-- R15: fase do SLA. Cliente = Aguardando Feedback; standby = Standby (relógio próprio); fechamento = Encerrado,
-- Negócio Fechado, Declinado..., Sem retorno...; equipe = todo o resto (Entrada, elaboração, revisão e status novos)
fases AS (
  SELECT
    *,
    CASE
      WHEN status = 'Aguardando Feedback' THEN 'cliente'
      WHEN LOWER(status) LIKE 'standby%' THEN 'standby'
      WHEN REGEXP_CONTAINS(LOWER(status), r'^(encerrado|neg[oó]cio fechado|declinado|sem retorno)') THEN 'fechamento'
      ELSE 'equipe'
    END AS fase
  FROM historico
),

-- R14: calendário sem expediente, calculado para cada ano (de 2020 até o ano seguinte ao atual)
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

-- R13: tempo no status, de entrada até fim. fim = saída; no status atual (sem saída), fim = agora (R17).
-- Útil = só o que cai em dia útil (seg–sex fora do calendário R14), das 10h às 19h (dia útil = 9 h)
tempo AS (
  SELECT
    h.*,
    DATETIME_DIFF(h.fim, h.entrada, SECOND) AS seg_corrido,
    (
      SELECT IFNULL(SUM(GREATEST(0, DATETIME_DIFF(
               LEAST(h.fim, DATETIME(d, TIME '19:00:00')),
               GREATEST(h.entrada, DATETIME(d, TIME '10:00:00')), SECOND))), 0)
      FROM UNNEST(GENERATE_DATE_ARRAY(DATE(h.entrada), DATE(h.fim))) AS d
      WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6  -- segunda a sexta
        AND d NOT IN UNNEST(f.dias)
    ) AS seg_util,
    -- R21: horário da mudança que encerrou o passo
    CASE
      WHEN h.saida IS NULL THEN NULL
      WHEN EXTRACT(DAYOFWEEK FROM h.saida) IN (1, 7) OR DATE(h.saida) IN UNNEST(f.dias) THEN 'fim de semana ou feriado'
      WHEN TIME(h.saida) < TIME '10:00:00' THEN 'antes do expediente'
      WHEN TIME(h.saida) >= TIME '19:00:00' THEN 'depois do expediente'
      ELSE 'expediente'
    END AS saida_horario
  FROM (
    SELECT fs.*, COALESCE(fs.saida, pr.agora) AS fim, fs.saida IS NULL AND fs.fase != 'fechamento' AS em_aberto
    FROM fases fs
    CROSS JOIN parametros pr
  ) h
  CROSS JOIN feriados f
),

-- R20: trabalho fora do expediente = uma pessoa (não a automação) fez a mudança fora do horário.
-- Hora extra estimada: depois do expediente = das 19h (ou da entrada, se depois) até a mudança;
-- antes do expediente ou em fim de semana/feriado = da entrada até a mudança, só se as duas forem no mesmo dia
-- (senão não dá para estimar: NULL)
extra AS (
  SELECT
    t.*,
    t.saida_horario != 'expediente' AND NOT COALESCE(t.saida_por_automacao, FALSE) AS fora_expediente,
    CASE
      WHEN t.saida_horario IS NULL OR t.saida_horario = 'expediente' OR COALESCE(t.saida_por_automacao, FALSE) THEN NULL
      WHEN t.saida_horario = 'depois do expediente'
        THEN DATETIME_DIFF(t.saida, GREATEST(t.entrada, DATETIME(DATE(t.saida), TIME '19:00:00')), SECOND)
      WHEN DATE(t.entrada) = DATE(t.saida) THEN DATETIME_DIFF(t.saida, t.entrada, SECOND)
    END AS seg_hora_extra
  FROM tempo t
)

SELECT
  p.projeto_id,
  p.item_id_atual,
  p.item_id_legado,
  p.board_id,
  p.nome_projeto,
  p.status_atual,
  p.talento,
  p.exclusivo,
  p.tipo_de_input,
  p.tipo_de_output,
  p.marca,
  o.orcamento,
  t.passo,
  t.status,
  t.fase,
  t.entrada,
  t.saida,
  -- R21: a mudança que encerrou o passo: horário, quem fez e se foi automação
  t.saida_horario,
  t.saida_por,
  t.saida_por_automacao,
  -- tempo do status concluído (NULL enquanto o status não termina)
  IF(t.saida IS NULL, NULL, ROUND(t.seg_corrido / 3600, 2)) AS sla_corrido_horas,
  IF(t.saida IS NULL, NULL, ROUND(t.seg_util / 3600, 2)) AS sla_util_horas,
  -- R20: mudança feita por uma pessoa fora do horário e a hora extra estimada
  t.fora_expediente,
  ROUND(t.seg_hora_extra / 3600, 2) AS hora_extra_horas,
  -- leitura: dias (24 h) e horas corridas
  IF(t.saida IS NULL, NULL,
     FORMAT('%dd %02dh%02d', DIV(t.seg_corrido, 86400), DIV(MOD(t.seg_corrido, 86400), 3600),
            DIV(MOD(t.seg_corrido, 3600), 60))) AS sla_corrido,
  -- leitura: dias úteis (9 h) e horas úteis
  IF(t.saida IS NULL, NULL,
     FORMAT('%dd %02dh%02d', DIV(t.seg_util, 32400), DIV(MOD(t.seg_util, 32400), 3600),
            DIV(MOD(t.seg_util, 3600), 60))) AS sla_util,
  -- R17: status atual ainda aberto (equipe, cliente ou standby) e há quanto tempo, até a execução; muda a cada execução
  t.em_aberto,
  IF(t.em_aberto, ROUND(t.seg_corrido / 3600, 2), NULL) AS aberto_ha_corrido_horas,
  IF(t.em_aberto, ROUND(t.seg_util / 3600, 2), NULL) AS aberto_ha_util_horas,
  -- R18: alerta = cliente sem retorno há mais que o limite (em dias úteis)
  t.em_aberto AND t.fase = 'cliente' AND t.seg_util > pr.alerta_dias_uteis_cliente * 32400 AS alerta,
  -- R19: marcações do fluxo, pela fase do passo anterior
  -- retrabalho: voltou do cliente (Aguardando Feedback) para a equipe
  COALESCE(t.fase = 'equipe'
    AND LAG(t.fase) OVER (PARTITION BY t.projeto_id ORDER BY t.passo) = 'cliente', FALSE) AS retrabalho,
  -- reaberto: saiu de um fechamento (Encerrado, Declinado...) e voltou a andar
  COALESCE(LAG(t.fase) OVER (PARTITION BY t.projeto_id ORDER BY t.passo) = 'fechamento', FALSE) AS reaberto,
  -- fechou vindo direto da equipe (ou do Standby), sem passar pelo cliente; Declinado (Internamente, pelo Mercado,
  -- pelo talento...) direto da equipe é o esperado e não é marcado. Separado em dois casos:
  -- entrega_sem_aguardando: o projeto já tinha ido ao cliente antes (ex.: retrabalho fechado sem registrar a nova entrega)
  COALESCE(t.fase = 'fechamento'
    AND NOT STARTS_WITH(LOWER(t.status), 'declinado')
    AND LAG(t.fase) OVER (PARTITION BY t.projeto_id ORDER BY t.passo) IN ('equipe', 'standby')
    AND LOGICAL_OR(t.fase = 'cliente') OVER (
          PARTITION BY t.projeto_id ORDER BY t.passo ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), FALSE)
    AS entrega_sem_aguardando,
  -- encerrado_sem_entrega: o projeto nunca tinha ido ao cliente (encerrado no meio do trabalho)
  COALESCE(t.fase = 'fechamento'
    AND NOT STARTS_WITH(LOWER(t.status), 'declinado')
    AND LAG(t.fase) OVER (PARTITION BY t.projeto_id ORDER BY t.passo) IN ('equipe', 'standby')
    AND NOT COALESCE(LOGICAL_OR(t.fase = 'cliente') OVER (
          PARTITION BY t.projeto_id ORDER BY t.passo ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING), FALSE), FALSE)
    AS encerrado_sem_entrega,
  p.link_projeto,
  CURRENT_TIMESTAMP() AS _processado_em
FROM extra t
JOIN projetos p USING (projeto_id)
LEFT JOIN orcamento o USING (projeto_id)
CROSS JOIN parametros pr
;

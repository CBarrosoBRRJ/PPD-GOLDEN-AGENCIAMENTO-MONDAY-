-- Roteiro de subida das golds do relatório. GERADO por tools/montar_subida.py a partir de deploy/ e
-- sql/validacoes/ (não editar à mão): se um SELECT, esquema ou validação mudar, rode
-- python tools/gerar_deploy.py e python tools/montar_subida.py.
-- Executar no console do BigQuery, conta caio.barroso@viu.com.br, projeto gglobo-viu-dados-hdg-prd, UM BLOCO POR VEZ,
-- conferindo a saída. Validação: toda linha com ok = true; parar se alguma vier false.
-- Depois de 28/10/2026 (reunião). Antes do 1º bloco: commit/push (deploy/gcp_setup.md).
-- Depois do último bloco: deploy do job com as tabelas novas em TABELAS, ensaio --dry-run e execução real
-- (deploy/gcp_setup.md, passo 4). Até lá as tabelas novas ficam com os dados do dia da criação e as views de
-- entregas da SLA com horas zero (a coluna R24 só é preenchida pelo job novo).

-- ============================================================================================================
-- BLOCO 1 — SLA: coluna nova sla_sem_almoco_horas (R24, sem almoço). NÃO usar o criar_ da SLA (recriaria a tabela e apagaria a permissão).
-- A coluna fica vazia até a próxima execução do job com o código novo.
-- ============================================================================================================

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
  ADD COLUMN IF NOT EXISTS sla_sem_almoco_horas FLOAT64;

-- BLOCO 2 — SLA: descrições (tabela e colunas, inclusive a nova)

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos` SET OPTIONS(description="SLA do board Backlog 2026 | Agenciamento: uma linha por passagem de um projeto por um status (projeto_id + passo), com fase (equipe, cliente, standby, fechamento), tempo corrido e útil, tempo em aberto, alerta e marcações do fluxo. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_sla_movimentos.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
  ALTER COLUMN projeto_id SET OPTIONS(description="Chave do projeto do início ao fim (igual à silver; atravessa a migração de 03/09/2026). Com passo, forma a chave da tabela"),
  ALTER COLUMN item_id_atual SET OPTIONS(description="ID do item no board atual do monday"),
  ALTER COLUMN item_id_legado SET OPTIONS(description="ID do item no board antigo (conta viu2); vazio nos projetos criados depois da migração"),
  ALTER COLUMN board_id SET OPTIONS(description="ID do board no monday"),
  ALTER COLUMN nome_projeto SET OPTIONS(description="Nome do projeto, como na silver"),
  ALTER COLUMN status_atual SET OPTIONS(description="Status do projeto hoje (foto do dia); serve para filtrar, ex.: só encerrados"),
  ALTER COLUMN talento SET OPTIONS(description="Talento do projeto (silver): um nome, Squad de Talentos (mais de um) ou vazio"),
  ALTER COLUMN exclusivo SET OPTIONS(description="O talento era exclusivo na data do projeto (silver); vazio sem talento"),
  ALTER COLUMN tipo_de_input SET OPTIONS(description="Tipo de input (forma oficial da silver)"),
  ALTER COLUMN tipo_de_output SET OPTIONS(description="Tipo de output (forma oficial da silver)"),
  ALTER COLUMN marca SET OPTIONS(description="Marca do projeto (Catálogo de Marcas, pela silver)"),
  ALTER COLUMN orcamento SET OPTIONS(description="Nome da pessoa da equipe de orçamento (R5); mais de uma = nomes separados por vírgula, na ordem do monday. É o responsável de hoje, não o da época de cada passo"),
  ALTER COLUMN passo SET OPTIONS(description="Ordem da passagem do projeto pelos status (1 = Entrada)"),
  ALTER COLUMN status SET OPTIONS(description="Status desta passagem (como no log; nomes antigos mantidos)"),
  ALTER COLUMN fase SET OPTIONS(description="Relógio do SLA (R15): equipe (Entrada, elaboração, revisão e status novos), cliente (Aguardando Feedback), standby (Standby, relógio próprio) ou fechamento (Encerrado, Negócio Fechado, Declinado, Sem retorno)"),
  ALTER COLUMN entrada SET OPTIONS(description="Quando o projeto chegou neste status (horário de Brasília)"),
  ALTER COLUMN saida SET OPTIONS(description="Quando o projeto mudou para o status seguinte (horário de Brasília); vazio = status atual"),
  ALTER COLUMN saida_horario SET OPTIONS(description="Horário da mudança que encerrou o passo (R21): expediente, antes do expediente, depois do expediente ou fim de semana ou feriado"),
  ALTER COLUMN saida_por SET OPTIONS(description="Quem fez a mudança que encerrou o passo (nome no monday; a automação aparece como Automação do monday)"),
  ALTER COLUMN saida_por_automacao SET OPTIONS(description="A mudança que encerrou o passo foi feita por uma automação (ex.: Encerrado automático 30 dias depois de Aguardando Feedback)"),
  ALTER COLUMN sla_corrido_horas SET OPTIONS(description="Tempo no status em horas corridas (saída − entrada; R13); vazio enquanto o status não termina"),
  ALTER COLUMN sla_util_horas SET OPTIONS(description="Tempo no status em horas úteis (R13): só seg–sex, 10h–19h, fora de feriados e dias sem expediente (R14); vazio enquanto o status não termina"),
  ALTER COLUMN fora_expediente SET OPTIONS(description="A mudança que encerrou o passo foi feita por uma pessoa fora do horário (R20); a automação não conta"),
  ALTER COLUMN hora_extra_horas SET OPTIONS(description="Hora extra estimada (R20): depois do expediente = das 19h (ou da entrada) até a mudança; antes do expediente ou fim de semana/feriado = da entrada até a mudança, só no mesmo dia; vazio quando não se aplica ou não dá para estimar"),
  ALTER COLUMN sla_corrido SET OPTIONS(description="Leitura do tempo corrido: Xd HHhMM (1 dia = 24 h)"),
  ALTER COLUMN sla_util SET OPTIONS(description="Leitura do tempo útil: Xd HHhMM (1 dia útil = 9 h)"),
  ALTER COLUMN em_aberto SET OPTIONS(description="Status atual ainda em andamento (fase equipe, cliente ou standby; R17)"),
  ALTER COLUMN aberto_ha_corrido_horas SET OPTIONS(description="Há quanto tempo o status atual está aberto, em horas corridas, até a execução (_processado_em); muda a cada execução"),
  ALTER COLUMN aberto_ha_util_horas SET OPTIONS(description="Há quanto tempo o status atual está aberto, em horas úteis, até a execução; muda a cada execução"),
  ALTER COLUMN alerta SET OPTIONS(description="Cliente sem retorno: em Aguardando Feedback, em aberto, há mais de 10 dias úteis (R18; limite provisório)"),
  ALTER COLUMN retrabalho SET OPTIONS(description="Voltou de Aguardando Feedback para um status da equipe (R19)"),
  ALTER COLUMN reaberto SET OPTIONS(description="Saiu de um fechamento (Encerrado, Declinado) e voltou a andar (R19)"),
  ALTER COLUMN entrega_sem_aguardando SET OPTIONS(description="Fechou vindo da equipe sem registrar a nova entrega em Aguardando Feedback, depois de já ter ido ao cliente (R19); Declinado não conta"),
  ALTER COLUMN encerrado_sem_entrega SET OPTIONS(description="Fechou vindo da equipe sem nunca ter ido ao cliente (R19); Declinado não conta"),
  ALTER COLUMN link_projeto SET OPTIONS(description="Link do projeto no monday"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução que gerou a tabela"),
  ALTER COLUMN sla_sem_almoco_horas SET OPTIONS(description="Tempo útil do status concluído sem o almoço, em horas, sem arredondar (R24): mesmos dias úteis do sla_util_horas, só das 10h às 13h e das 14h às 19h (dia útil = 8 h); NULL enquanto o status não termina. Nunca maior que sla_util_horas (fora o arredondamento dele, de 2 casas)");

-- ============================================================================================================
-- BLOCO 3 — TABELA gld_agenciamento_2026_talentos_ano (uma linha por ano × categoria). Cria já com os dados de hoje.
-- ============================================================================================================

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
(
  ano INT64 OPTIONS(description="Ano dos pedidos (o de ontem). Conta de 1º/jan até ontem, pela data de entrada da gld_agenciamento_entrada_diaria (criado_em; cadastro retroativo pela data_de_entrada; sem criado_em, data_de_saida − 5 dias úteis)"),
  categoria STRING OPTIONS(description="Exclusivos, Não exclusivos (inclui Squad de Talentos) ou Sem talento (exclusividade nula na silver). Com ano, forma a chave"),
  n INT64 OPTIONS(description="Pedidos (cards ativos do board 2026) da categoria no ano"),
  total INT64 OPTIONS(description="Pedidos do ano nas três categorias; igual às entradas do ano na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  pct FLOAT64 OPTIONS(description="Participação da categoria em %, 1 casa decimal; as três somam 100,0 (maior resto)"),
  dos_quais_squad INT64 OPTIONS(description="Dos pedidos da categoria, quantos têm talento Squad de Talentos (um grupo, não uma pessoa)"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução")
)
CLUSTER BY ano, categoria
OPTIONS(
  description="Divisão anual dos pedidos do board 2026 entre Exclusivos, Não exclusivos (inclui Squad de Talentos) e Sem talento, de 1º/jan até ontem, com a exclusividade na data do pedido (silver) e as regras de data da gld_agenciamento_entrada_diaria; o total é igual às entradas do ano da diária. Uma linha por categoria. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_talentos_ano.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "talentos-ano")]
)
AS
-- gold_monday.gld_agenciamento_2026_talentos_ano — divisão anual dos pedidos entre exclusivos, não exclusivos e sem
-- talento (board 2026). Ficha: docs/tabelas/gld_agenciamento_2026_talentos_ano.md.
-- Origem: tools/preparar_gold_relatorio.py do PPD-AGENCIAMENTO-SLA (contrato talentos_ano, auditoria de 26/10/2026),
-- que reproduz app/sql/talentos_ano.sql do site (exceção D30-b de lá). Mesma população e mesmas regras de data da
-- gld_agenciamento_entrada_diaria (R1, R2, R4, R5, R21), mas só o board 2026: a exclusividade só existe nele.
-- O ano é o de ontem; conta de 1º/jan até ontem. Percentuais com 1 casa, fechando 100,0% pelo maior resto.
WITH parametros AS (
  SELECT
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,                    -- R4: até ontem
    DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR) AS inicio
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_entrada_diaria (copiado igual; serve à data estimada R2)
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

pedidos AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(
      IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
         DATE(i.criado_em)),
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(i.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(i.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    i.talento,
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

contagem AS (
  SELECT
    EXTRACT(YEAR FROM p.dia) AS ano,
    CASE
      WHEN p.exclusivo THEN 'Exclusivos'
      WHEN NOT p.exclusivo THEN 'Não exclusivos'      -- inclui "Squad de Talentos" (regra 60 da silver)
      ELSE 'Sem talento'
    END AS categoria,
    COUNT(*) AS n,
    COUNTIF(p.talento = 'Squad de Talentos') AS dos_quais_squad
  FROM pedidos p
  CROSS JOIN parametros pr
  WHERE p.dia BETWEEN pr.inicio AND pr.fim                                   -- R4: até ontem
  GROUP BY ano, categoria
),

-- maior resto: décimos de ponto percentual (1000 = 100,0%)
partes AS (
  SELECT *, SUM(n) OVER () AS total,
    DIV(n * 1000, SUM(n) OVER ()) AS base,
    MOD(n * 1000, SUM(n) OVER ()) AS resto
  FROM contagem
)

SELECT
  ano,
  categoria,
  n,
  total,
  (base + IF(ROW_NUMBER() OVER (ORDER BY resto DESC, n DESC) <= 1000 - SUM(base) OVER (), 1, 0)) / 10 AS pct,
  dos_quais_squad,
  CURRENT_TIMESTAMP() AS _processado_em
FROM partes
;

-- BLOCO 4 — validação de gld_agenciamento_2026_talentos_ano (confere contra: entrada_diaria)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', ano, categoria)) AS chaves,
    COUNT(DISTINCT ano) AS anos,
    COUNTIF(categoria NOT IN ('Exclusivos', 'Não exclusivos', 'Sem talento')) AS categoria_invalida,
    COUNTIF(n IS NULL OR n < 0 OR dos_quais_squad < 0 OR dos_quais_squad > n) AS contagem_invalida,
    SUM(n) AS pedidos,
    COUNT(DISTINCT total) AS totais,
    ANY_VALUE(total) AS total,
    ROUND(SUM(pct), 1) AS soma_pct,
    ANY_VALUE(ano) AS ano,
    STRING_AGG(FORMAT('%s: %d (%.1f%%)', categoria, n, pct), ' | '
      ORDER BY CASE categoria WHEN 'Exclusivos' THEN 1 WHEN 'Não exclusivos' THEN 2 ELSE 3 END) AS texto,
    SUM(dos_quais_squad) AS squad
  FROM t
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

diaria AS (
  SELECT SUM(quantidade + quantidade_estimada) AS entradas
  FROM d, ontem o
  WHERE d.data BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, diaria e, ontem o, UNNEST([
  STRUCT(
    'chave ano × categoria única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('um ano só (o de ontem)', CAST(r.anos AS STRING), '1',
    r.anos = 1 AND r.ano = EXTRACT(YEAR FROM o.dia)
    OR r.linhas = 0 AND EXTRACT(MONTH FROM o.dia) = 1),
  ('tabela vazia no começo do ano (aceita só em janeiro)', CAST(IF(r.linhas = 0, 1, 0) AS STRING), 'aviso', TRUE),
  ('categoria fora de Exclusivos, Não exclusivos, Sem talento', CAST(r.categoria_invalida AS STRING), '0',
    r.categoria_invalida = 0),
  ('contagens nulas, negativas ou squad maior que a categoria', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('total igual em todas as linhas e = soma das categorias', FORMAT('%d (soma %d)', r.total, r.pedidos),
    'total = soma', r.linhas = 0 OR r.totais = 1 AND r.total = r.pedidos),
  ('soma das categorias = entradas do ano na diária (quantidade + quantidade_estimada)',
    CAST(IFNULL(r.pedidos, 0) AS STRING), CAST(IFNULL(e.entradas, 0) AS STRING),
    IFNULL(r.pedidos, 0) = IFNULL(e.entradas, 0)),
  ('percentuais somam 100,0', FORMAT('%.1f', r.soma_pct), '100.0', r.linhas = 0 OR r.soma_pct = 100),
  ('divisão do ano (26/10/2026: Exclusivos 3.451 | Não exclusivos 1.980 | Sem talento 125)', r.texto,
    'informativo', TRUE),
  ('Squad de Talentos (dentro de Não exclusivos; 26/10/2026: 119)', CAST(r.squad AS STRING), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 5 — TABELA gld_agenciamento_2026_talentos_ranking (uma linha por recorte × talento × mês). Cria já com os dados de hoje.
-- ============================================================================================================

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ranking`
(
  grupo STRING OPTIONS(description="Recorte: todos (exclusivos + não exclusivos pelo mesmo nome), exclusivo ou nao-exclusivo. Com talento e mes, forma a chave"),
  talento STRING OPTIONS(description="Nome do talento na grafia mais frequente do recorte (agrupado sem diferença de maiúsculas e espaços). Sem Squad de Talentos e sem pedidos sem talento"),
  n INT64 OPTIONS(description="Pedidos do talento no ano (1º/jan até ontem), no recorte; repete em todas as linhas do talento"),
  ultimo_pedido DATE OPTIONS(description="Data de entrada do último pedido do talento no ano, no recorte"),
  empate_fora INT64 OPTIONS(description="Talentos do recorte fora da lista com o mesmo número de pedidos do 10º lugar (a tela mostra \"empate com mais N\"); repete no recorte"),
  talentos_grupo INT64 OPTIONS(description="Talentos nomeados com pedido no ano, no recorte; repete no recorte"),
  mes DATE OPTIONS(description="1º dia do mês dos pedidos (mês da data de entrada); só meses com pedido do talento"),
  n_mes INT64 OPTIONS(description="Pedidos do talento no mês, no recorte"),
  pos INT64 OPTIONS(description="Lugar do talento no ano, no recorte (1 = mais pedidos; empate pela ordem alfabética). pos > 10 = esteve entre os 10 do acumulado no fim de algum mês, mas não fechou o ano entre os 10"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução")
)
CLUSTER BY grupo, pos
OPTIONS(
  description="Ranking de talentos do board 2026 no ano (1º/jan até ontem), por recorte (todos, exclusivo, nao-exclusivo): os 10 com mais pedidos e os que passaram pelos 10 do acumulado no fim de algum mês (corrida do ano), com os pedidos de cada um mês a mês. Mesma população da gld_agenciamento_2026_talentos_ano; sem Squad de Talentos e sem pedidos sem talento. Uma linha por recorte × talento × mês com pedido. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_talentos_ranking.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "talentos-ranking")]
)
AS
-- gold_monday.gld_agenciamento_2026_talentos_ranking — os 10 talentos com mais pedidos no ano em cada recorte
-- (todos, exclusivo, nao-exclusivo), mês a mês, e quem passou pelos 10 do acumulado (corrida do ano). Board 2026.
-- Ficha: docs/tabelas/gld_agenciamento_2026_talentos_ranking.md.
-- Origem: tools/preparar_gold_relatorio.py do PPD-AGENCIAMENTO-SLA (contrato talentos_ranking, auditoria de
-- 26/10/2026), que reproduz app/sql/talentos_top.sql do site (D50, D51). Mesma população e regras de data da
-- gld_agenciamento_2026_talentos_ano: o mês do pedido é o mês da data de entrada.
-- Um talento por pedido (duplas como "Bruno e Marrone" são um talento). Nomes agrupados sem diferença de maiúsculas e
-- espaços e mostrados na grafia mais frequente; "Squad de Talentos" (um grupo) e pedido sem talento ficam fora.
-- "todos" = exclusivos + não exclusivos pelo mesmo nome (quem mudou de vínculo no ano soma os dois). Empate: alfabética.
-- empate_fora: talentos fora da lista com o mesmo número de pedidos do 10º lugar ("empate com mais N" na tela).
-- Uma linha por (grupo, talento, mês com pedido); n = pedidos no ano, n_mes = no mês, talentos_grupo = talentos com
-- pedido no ano no recorte, pos = lugar no ano. Além dos 10 do ano (pos <= 10), vêm os que estiveram entre os 10 do
-- ACUMULADO no fim de algum mês (pos > 10); ranking do acumulado com desempate pelo lugar no ano.
WITH parametros AS (
  SELECT
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,                    -- R4: até ontem
    DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR) AS inicio
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_entrada_diaria (copiado igual; serve à data estimada R2)
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

pedidos AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(
      IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
         DATE(i.criado_em)),
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(i.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(i.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    i.talento,
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

-- pedidos do ano com talento nomeado, já no recorte (um pedido entra no seu grupo e em "todos")
validos AS (
  SELECT g AS grupo, p.dia, DATE_TRUNC(p.dia, MONTH) AS mes,
    LOWER(REGEXP_REPLACE(TRIM(p.talento), r'\s+', ' ')) AS chave,
    REGEXP_REPLACE(TRIM(p.talento), r'\s+', ' ') AS talento
  FROM pedidos p
  CROSS JOIN parametros pr
  CROSS JOIN UNNEST([IF(p.exclusivo, 'exclusivo', 'nao-exclusivo'), 'todos']) AS g
  WHERE p.dia BETWEEN pr.inicio AND pr.fim AND p.exclusivo IS NOT NULL
    AND LOWER(REGEXP_REPLACE(TRIM(COALESCE(p.talento, '')), r'\s+', ' ')) NOT IN ('', 'squad de talentos')
),

grafias AS (
  SELECT grupo, chave, talento, COUNT(*) AS n, MAX(dia) AS ultimo_pedido
  FROM validos GROUP BY grupo, chave, talento
),
ranking AS (
  SELECT grupo, chave, ARRAY_AGG(talento ORDER BY n DESC, talento LIMIT 1)[OFFSET(0)] AS talento,
    SUM(n) AS n, MAX(ultimo_pedido) AS ultimo_pedido
  FROM grafias GROUP BY grupo, chave
),

ranqueado AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY grupo ORDER BY n DESC, talento) AS pos,
    COUNT(*) OVER (PARTITION BY grupo) AS talentos_grupo                      -- talentos com pedido no ano, no recorte
  FROM ranking
),
fora AS (
  SELECT x.grupo, COUNT(*) AS empate_fora
  FROM ranqueado x JOIN ranqueado c ON c.grupo = x.grupo AND c.pos = 10 AND x.n = c.n
  WHERE x.pos > 10
  GROUP BY x.grupo
),

por_mes AS (
  SELECT grupo, chave, mes, COUNT(*) AS n_mes FROM validos GROUP BY grupo, chave, mes
),

-- D51: acumulado de cada talento no fim de cada mês do ano (meses com pedido no recorte) e quem passou pelos 10
acumulado AS (
  SELECT ms.grupo, ms.mes, r.chave, r.pos, SUM(IF(m.mes <= ms.mes, m.n_mes, 0)) AS ate_o_mes
  FROM (SELECT DISTINCT grupo, mes FROM validos) ms
  JOIN ranqueado r ON r.grupo = ms.grupo
  JOIN por_mes m ON m.grupo = r.grupo AND m.chave = r.chave
  GROUP BY ms.grupo, ms.mes, r.chave, r.pos
),
na_corrida AS (
  SELECT DISTINCT grupo, chave
  FROM (SELECT grupo, chave, ROW_NUMBER() OVER (PARTITION BY grupo, mes ORDER BY ate_o_mes DESC, pos) AS lugar
        FROM acumulado)
  WHERE lugar <= 10
)

SELECT r.grupo, r.talento, r.n, r.ultimo_pedido, COALESCE(f.empate_fora, 0) AS empate_fora, r.talentos_grupo, m.mes,
  m.n_mes, r.pos, CURRENT_TIMESTAMP() AS _processado_em
FROM ranqueado r
LEFT JOIN fora f USING (grupo)
LEFT JOIN na_corrida c ON c.grupo = r.grupo AND c.chave = r.chave
JOIN por_mes m ON m.grupo = r.grupo AND m.chave = r.chave
WHERE r.pos <= 10 OR c.chave IS NOT NULL
;

-- BLOCO 6 — validação de gld_agenciamento_2026_talentos_ranking (confere contra: talentos_ano)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ranking`
),

a AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
),

por_talento AS (
  SELECT grupo, talento, COUNT(DISTINCT n) AS ns, ANY_VALUE(n) AS n, COUNT(DISTINCT pos) AS poss, ANY_VALUE(pos) AS pos,
    SUM(n_mes) AS soma_meses, MAX(mes) AS ultimo_mes, ANY_VALUE(ultimo_pedido) AS ultimo_pedido,
    ANY_VALUE(talentos_grupo) AS talentos_grupo
  FROM t
  GROUP BY grupo, talento
),

por_grupo AS (
  SELECT grupo,
    LEAST(10, MAX(talentos_grupo)) AS top_esperado,
    COUNTIF(pos <= 10) AS no_top,
    COUNT(DISTINCT IF(pos <= 10, pos, NULL)) AS lugares,
    SUM(IF(pos <= 10, n, 0)) AS pedidos_top,
    COUNTIF(pos > 10) AS so_na_corrida,
    ARRAY_AGG(IF(pos = 1, FORMAT('%s (%d)', talento, n), NULL) IGNORE NULLS)[SAFE_OFFSET(0)] AS primeiro
  FROM por_talento
  GROUP BY grupo
),

base AS (
  SELECT SUM(IF(categoria = 'Exclusivos', n, 0)) AS ex, SUM(IF(categoria = 'Não exclusivos', n, 0)) AS nex FROM a
),

conc AS (
  SELECT g.grupo, g.pedidos_top,
    CASE g.grupo WHEN 'exclusivo' THEN b.ex WHEN 'nao-exclusivo' THEN b.nex ELSE b.ex + b.nex END AS pedidos_recorte
  FROM por_grupo g CROSS JOIN base b
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t|%t', grupo, LOWER(talento), mes)) AS chaves,
    COUNTIF(grupo NOT IN ('todos', 'exclusivo', 'nao-exclusivo')) AS grupo_invalido,
    COUNTIF(n IS NULL OR n_mes IS NULL OR n <= 0 OR n_mes <= 0 OR n_mes > n) AS contagem_invalida,
    COUNTIF(mes NOT BETWEEN DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR)
                        AND DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY)
            OR mes != DATE_TRUNC(mes, MONTH)) AS mes_fora,
    COUNTIF(LOWER(TRIM(talento)) IN ('', 'squad de talentos') OR talento IS NULL) AS talento_invalido,
    COUNT(DISTINCT IF(talentos_grupo < 10, grupo, NULL)) AS grupo_pequeno
  FROM t
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, ontem o, UNNEST([
  STRUCT(
    'chave grupo × talento × mês única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('grupo fora de todos, exclusivo, nao-exclusivo', CAST(r.grupo_invalido AS STRING), '0', r.grupo_invalido = 0),
  ('recortes presentes (menos de 3 só em janeiro)', (SELECT CAST(COUNT(*) AS STRING) FROM por_grupo), '3',
    (SELECT COUNT(*) FROM por_grupo) = 3 OR EXTRACT(MONTH FROM o.dia) = 1),
  ('talento vazio, nulo ou Squad de Talentos', CAST(r.talento_invalido AS STRING), '0', r.talento_invalido = 0),
  ('contagens nulas, não positivas ou mês maior que o ano', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('mês fora do ano de ontem ou que não é 1º dia', CAST(r.mes_fora AS STRING), '0', r.mes_fora = 0),
  ('recortes com menos de 10 talentos no ano (começo de ano)', CAST(r.grupo_pequeno AS STRING), 'aviso', TRUE),
  ('talentos com n, pos ou último pedido incoerentes entre os meses, ou n ≠ soma dos meses',
    (SELECT CAST(COUNTIF(ns > 1 OR poss > 1 OR n != soma_meses OR ultimo_mes != DATE_TRUNC(ultimo_pedido, MONTH))
            AS STRING) FROM por_talento), '0',
    (SELECT COUNTIF(ns > 1 OR poss > 1 OR n != soma_meses OR ultimo_mes != DATE_TRUNC(ultimo_pedido, MONTH)) = 0
     FROM por_talento)),
  ('recortes sem top completo (lugares 1 a 10, ou 1 a N quando o recorte tem N < 10 talentos)',
    (SELECT CAST(COUNTIF(no_top != top_esperado OR lugares != top_esperado) AS STRING) FROM por_grupo), '0',
    (SELECT COUNTIF(no_top != top_esperado OR lugares != top_esperado) = 0 FROM por_grupo)),
  ('top 10 com mais pedidos que a categoria na gld_agenciamento_2026_talentos_ano (recortes)',
    (SELECT STRING_AGG(FORMAT('%s: %d de %d', grupo, pedidos_top, pedidos_recorte), ' | ' ORDER BY grupo) FROM conc),
    'top ≤ categoria', (SELECT COUNTIF(pedidos_top > pedidos_recorte) = 0 FROM conc)),
  ('1º lugar por recorte',
    (SELECT STRING_AGG(FORMAT('%s: %s', grupo, primeiro), ' | ' ORDER BY grupo) FROM por_grupo), 'informativo', TRUE),
  ('talentos só na corrida do acumulado (pos > 10), por recorte',
    (SELECT STRING_AGG(FORMAT('%s: %d', grupo, so_na_corrida), ' | ' ORDER BY grupo) FROM por_grupo), 'informativo',
    TRUE)
]);

-- ============================================================================================================
-- BLOCO 7 — TABELA gld_agenciamento_2026_saidas_status (uma linha por mês × status). Cria já com os dados de hoje.
-- ============================================================================================================

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status`
(
  mes DATE OPTIONS(description="1º dia do mês do evento: mês em que o card chegou ao status final, pela última entrada nele no log; nunca antes do mês de entrada; sem data no log = mês de entrada. Com status, forma a chave"),
  status STRING OPTIONS(description="Status atual do board que encerrou o card sem entrega: Declinado (e variações que começam por Declinado), Standby ou Encerrado"),
  n INT64 OPTIONS(description="Cards que entraram no ano (1º/jan até ontem) e saíram sem entrega com esse status nesse mês. Soma do mês = nao_seguiu do mês na gld_agenciamento_fluxo_mensal (safra do ano)"),
  sem_data INT64 OPTIONS(description="Dos n, quantos não têm a chegada ao status no log (contados no mês de entrada; no fluxo ficam com mes_evento NULL)"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução")
)
CLUSTER BY mes, status
OPTIONS(
  description="Saídas sem entrega do board 2026 por mês do evento e status final (Declinado*, Standby, Encerrado), para os cards que entraram no ano (1º/jan até ontem): a composição do evento nao_seguiu da gld_agenciamento_fluxo_mensal, que não guarda o status. Mesmas regras do fluxo; sem data no log, mês de entrada. Uma linha por mês × status. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_saidas_status.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "saidas-status")]
)
AS
-- gold_monday.gld_agenciamento_2026_saidas_status — composição por STATUS do board das saídas sem entrega
-- (Declinado*, Standby, Encerrado) dos pedidos que entraram no ano, por mês do evento. Board 2026.
-- Ficha: docs/tabelas/gld_agenciamento_2026_saidas_status.md.
-- Origem: tools/preparar_gold_relatorio.py do PPD-AGENCIAMENTO-SLA (contrato atendimento_status, auditoria de
-- 26/10/2026), que reproduz app/sql/saidas_status.sql do site (A26, D53). Lê só a silver (itens + log) com as mesmas
-- regras da gld_agenciamento_fluxo_mensal para o evento nao_seguiu (R1, R2, R4, R5, R12–R14, R16–R19, R21, F3, F4):
-- o fluxo não guarda o status, por isso esta tabela existe.
-- Mês do evento = mês em que o card chegou ao status final (última entrada nele, pelo log); antes do mês de entrada vira
-- o mês de entrada (F4); sem data no log = mês de entrada (S1, convenção E7 do site; no fluxo fica mes_evento NULL).
WITH parametros AS (
  SELECT
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,                    -- R4: até ontem
    DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR) AS inicio
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_entrada_diaria (copiado igual; serve à data estimada R2)
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

-- R12: 1ª entrada em Aguardando Feedback (1ª entrega ao cliente), pelo log
aguardando_feedback AS (
  SELECT projeto_id, MIN(DATE(alterado_em)) AS dia
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE campo_alterado = 'Status' AND valor_depois = 'Aguardando Feedback'
  GROUP BY projeto_id
),

-- F3: última entrada de cada projeto em cada status; ligada ao status atual = dia em que chegou ao status final
ultima_entrada_status AS (
  SELECT projeto_id, valor_depois AS status, MAX(DATE(alterado_em)) AS dia
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_log`
  WHERE campo_alterado = 'Status'
  GROUP BY projeto_id, valor_depois
),

itens AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
       DATE(i.criado_em)) AS criado,
    i.data_de_saida, af.dia AS aguardando, i.status, ue.dia AS status_desde
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  LEFT JOIN aguardando_feedback af USING (projeto_id)
  LEFT JOIN ultima_entrada_status ue ON ue.projeto_id = i.projeto_id AND ue.status = i.status
  WHERE i.state = 'active'                                                   -- R5
),

cards AS (
  SELECT
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(c.criado,
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(c.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(c.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    -- R12–R14: saída válida = Aguardando Feedback pelo log; sem ela, a data_de_saida; antes da entrada não vale
    CASE
      WHEN c.aguardando >= c.criado OR (c.aguardando IS NOT NULL AND c.criado IS NULL) THEN c.aguardando
      WHEN c.data_de_saida >= c.criado OR c.criado IS NULL THEN c.data_de_saida
    END AS saida,
    c.status, c.status_desde
  FROM itens c
  CROSS JOIN feriados f
)

SELECT
  -- F4 + E7: mês do evento nunca antes do mês de entrada; sem data no log = mês de entrada
  COALESCE(GREATEST(DATE_TRUNC(c.status_desde, MONTH), DATE_TRUNC(c.dia, MONTH)), DATE_TRUNC(c.dia, MONTH)) AS mes,
  c.status,
  COUNT(*) AS n,
  COUNTIF(c.status_desde IS NULL) AS sem_data,
  CURRENT_TIMESTAMP() AS _processado_em
FROM cards c
CROSS JOIN parametros pr
WHERE c.dia BETWEEN pr.inicio AND pr.fim                                     -- R4: safra do ano até a véspera da carga
  -- R16–R19: sem saída válida até ontem e com status final = não seguiu (saiu sem entrega)
  AND NOT IFNULL(c.saida <= pr.fim, FALSE)
  AND (STARTS_WITH(c.status, 'Declinado') OR c.status IN ('Standby', 'Encerrado'))
GROUP BY mes, c.status
;

-- BLOCO 8 — validação de gld_agenciamento_2026_saidas_status (confere contra: fluxo_mensal)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status`
),

f AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

por_mes AS (
  SELECT
    COALESCE(a.mes, b.mes) AS mes, IFNULL(a.n, 0) AS status, IFNULL(b.n, 0) AS fluxo
  FROM (SELECT mes, SUM(n) AS n FROM t GROUP BY mes) a
  FULL JOIN (
    SELECT COALESCE(f.mes_evento, f.mes_entrada) AS mes, SUM(f.quantidade) AS n
    FROM f, ontem o
    WHERE f.evento = 'nao_seguiu' AND EXTRACT(YEAR FROM f.mes_entrada) = EXTRACT(YEAR FROM o.dia)
    GROUP BY mes) b
  USING (mes)
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, status)) AS chaves,
    COUNTIF(status IS NULL OR NOT (STARTS_WITH(status, 'Declinado') OR status IN ('Standby', 'Encerrado')))
      AS status_invalido,
    COUNTIF(n IS NULL OR n <= 0 OR sem_data < 0 OR sem_data > n) AS contagem_invalida,
    COUNTIF(mes NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia OR mes != DATE_TRUNC(mes, MONTH)) AS mes_fora,
    SUM(n) AS saidas,
    SUM(sem_data) AS sem_data,
    STRING_AGG(DISTINCT status, ', ' ORDER BY status) AS status_vistos
  FROM t, ontem o
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, UNNEST([
  STRUCT(
    'chave mês × status única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('status fora de Declinado*, Standby, Encerrado', CAST(r.status_invalido AS STRING), '0', r.status_invalido = 0),
  ('contagens nulas, não positivas ou sem_data maior que n', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('mês fora do ano de ontem ou que não é 1º dia', CAST(r.mes_fora AS STRING), '0', r.mes_fora = 0),
  -- IFNULL: no começo de janeiro as duas podem estar vazias (0 = 0)
  ('total = nao_seguiu da safra do ano no fluxo mensal', CAST(IFNULL(r.saidas, 0) AS STRING),
    (SELECT CAST(IFNULL(SUM(fluxo), 0) AS STRING) FROM por_mes),
    IFNULL(r.saidas, 0) = (SELECT IFNULL(SUM(fluxo), 0) FROM por_mes)),
  ('meses com soma dos status ≠ nao_seguiu do fluxo (mês do evento; sem data = mês de entrada)',
    IFNULL((SELECT STRING_AGG(FORMAT('%s: %d ≠ %d', FORMAT_DATE('%Y-%m', mes), status, fluxo), ' | ' ORDER BY mes)
            FROM por_mes WHERE status != fluxo), '0'),
    '0', (SELECT COUNTIF(status != fluxo) = 0 FROM por_mes)),
  ('saídas sem entrega por mês', (SELECT STRING_AGG(FORMAT('%s: %d', FORMAT_DATE('%Y-%m', mes), status), ' | '
    ORDER BY mes) FROM por_mes), 'informativo', TRUE),
  ('sem data no log (contados no mês de entrada)', CAST(r.sem_data AS STRING), 'informativo', TRUE),
  ('status vistos', r.status_vistos, 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 9 — TABELA gld_agenciamento_2026_previsao_exclusividade_diaria (uma linha por dia × tipo). Cria já com os dados de hoje.
-- ============================================================================================================

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
(
  data DATE OPTIONS(description="Dia de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), todo dia de 1º/jan até ontem, com zero quando não há pedido. Com tipo, forma a chave"),
  tipo STRING OPTIONS(description="Tipo de input da silver: Inbound ou Mercado (as séries da previsão de demanda)"),
  dia_util BOOL OPTIONS(description="TRUE = segunda a sexta fora do calendário sem expediente (feriados nacionais, RJ, SP, Carnaval, Cinzas, Sexta-feira Santa, Corpus Christi e vésperas de Natal e Ano-Novo)"),
  exclusivos INT64 OPTIONS(description="Pedidos com talento exclusivo na data do pedido"),
  nao_exclusivos INT64 OPTIONS(description="Pedidos com talento não exclusivo na data do pedido (inclui Squad de Talentos)"),
  sem_talento INT64 OPTIONS(description="Pedidos sem exclusividade definida na silver (sem talento)"),
  total INT64 OPTIONS(description="exclusivos + nao_exclusivos + sem_talento; igual às entradas do dia e tipo na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução")
)
CLUSTER BY data, tipo
OPTIONS(
  description="Pedidos do board 2026 por dia de entrada e tipo de input (Inbound, Mercado), divididos em exclusivos, não exclusivos e sem talento (exclusividade na data do pedido), todo dia de 1º/jan até ontem, com zero quando não há pedido; dia_util marca seg–sex fora dos feriados. O total de cada dia e tipo é igual às entradas da gld_agenciamento_entrada_diaria. Base das séries da previsão de demanda (a mensal é view sobre esta). Uma linha por dia × tipo. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "previsao-exclusividade-diaria")]
)
AS
-- gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria — pedidos do ano por dia e tipo de input (Inbound, Mercado), divididos
-- em exclusivos, não exclusivos e sem talento. Board 2026. Ficha: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md.
-- Base da previsão de exclusividade: a gld_agenciamento_2026_previsao_exclusividade_mensal (view) soma esta tabela por mês. Origem: contrato previsao_exclusividade
-- do PPD-AGENCIAMENTO-SLA (auditoria de 26/10/2026), série de exclusividade de ml/dados.py do site (página Previsão).
-- Mesma população e regras de data e de exclusividade da gld_agenciamento_2026_talentos_ano.
-- PD1: calendário completo — todo dia de 1º/jan até ontem, nos dois tipos, com zero quando não há pedido (diferente
-- das outras golds, que não gravam zeros: aqui a série é o produto, e a mensal nunca fica com buraco).
WITH parametros AS (
  SELECT
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,                    -- R4: até ontem
    DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR) AS inicio
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_entrada_diaria (copiado igual; serve à data estimada R2)
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

pedidos AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(
      IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
         DATE(i.criado_em)),
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(i.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(i.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    i.talento,
    i.tipo_de_input,
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

-- PD1: todos os dias do ano até ontem × os dois tipos da previsão (P2)
calendario AS (
  SELECT dia, tipo, NOT (EXTRACT(DAYOFWEEK FROM dia) IN (1, 7) OR dia IN UNNEST(f.dias)) AS dia_util
  FROM parametros pr
  CROSS JOIN feriados f
  CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(pr.inicio, pr.fim)) AS dia
  CROSS JOIN UNNEST(['Inbound', 'Mercado']) AS tipo
),

contagem AS (
  SELECT
    p.dia,
    p.tipo_de_input AS tipo,
    COUNTIF(p.exclusivo) AS exclusivos,
    COUNTIF(NOT p.exclusivo) AS nao_exclusivos,
    COUNTIF(p.exclusivo IS NULL) AS sem_talento,
    COUNT(*) AS total
  FROM pedidos p CROSS JOIN parametros pr
  WHERE p.dia BETWEEN pr.inicio AND pr.fim                                   -- R4: até ontem
    AND p.tipo_de_input IN ('Inbound', 'Mercado')                           -- P2: as séries da previsão
  GROUP BY p.dia, tipo
)

SELECT
  c.dia AS data,
  c.tipo,
  -- PD2: dia útil = seg–sex fora do calendário sem expediente (R3), para os modelos separarem fim de semana e feriado
  c.dia_util,
  IFNULL(n.exclusivos, 0) AS exclusivos,
  IFNULL(n.nao_exclusivos, 0) AS nao_exclusivos,
  IFNULL(n.sem_talento, 0) AS sem_talento,
  IFNULL(n.total, 0) AS total,
  CURRENT_TIMESTAMP() AS _processado_em
FROM calendario c
LEFT JOIN contagem n USING (dia, tipo)
;

-- BLOCO 10 — validação de gld_agenciamento_2026_previsao_exclusividade_diaria (confere contra: entrada_diaria, talentos_ano)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

a AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

comparacao AS (
  SELECT COALESCE(x.data, y.data) AS data, COALESCE(x.tipo, y.tipo) AS tipo, IFNULL(x.n, 0) AS tabela,
    IFNULL(y.n, 0) AS diaria
  FROM (SELECT data, tipo, total AS n FROM t) x
  FULL JOIN (
    SELECT d.data, d.tipo_de_input AS tipo, SUM(d.quantidade + d.quantidade_estimada) AS n
    FROM d, ontem o
    WHERE d.tipo_de_input IN ('Inbound', 'Mercado') AND d.data BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia
    GROUP BY d.data, tipo) y
  ON x.data = y.data AND x.tipo = y.tipo
),

ano AS (
  -- IFNULL: no começo de janeiro a talentos_ano pode estar vazia
  SELECT IFNULL(SUM(IF(categoria = 'Exclusivos', n, 0)), 0) AS ex,
    IFNULL(SUM(IF(categoria = 'Não exclusivos', n, 0)), 0) AS nex,
    IFNULL(SUM(IF(categoria = 'Sem talento', n, 0)), 0) AS sem
  FROM a
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', data, tipo)) AS chaves,
    2 * (DATE_DIFF(ANY_VALUE(o.dia), DATE_TRUNC(ANY_VALUE(o.dia), YEAR), DAY) + 1) AS esperadas,
    COUNTIF(tipo NOT IN ('Inbound', 'Mercado')) AS tipo_invalido,
    COUNTIF(exclusivos IS NULL OR nao_exclusivos IS NULL OR sem_talento IS NULL OR total IS NULL OR dia_util IS NULL
            OR exclusivos < 0 OR nao_exclusivos < 0 OR sem_talento < 0) AS contagem_invalida,
    COUNTIF(exclusivos + nao_exclusivos + sem_talento != total) AS partes_nao_somam,
    COUNTIF(data NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia) AS data_fora,
    COUNTIF(dia_util AND EXTRACT(DAYOFWEEK FROM data) IN (1, 7)) AS fim_de_semana_util,
    COUNTIF(NOT dia_util AND EXTRACT(DAYOFWEEK FROM data) BETWEEN 2 AND 6) / 2 AS feriados_seg_sex,
    COUNTIF(dia_util) / 2 AS dias_uteis,
    IFNULL(SUM(exclusivos), 0) AS ex, IFNULL(SUM(nao_exclusivos), 0) AS nex, IFNULL(SUM(sem_talento), 0) AS sem,
    SUM(IF(NOT dia_util, total, 0)) AS pedidos_fora_dia_util
  FROM t, ontem o
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, ano n, UNNEST([
  STRUCT(
    'chave dia × tipo única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('calendário completo: todo dia de 1º/jan até ontem, nos dois tipos (PD1)', CAST(r.linhas AS STRING),
    CAST(r.esperadas AS STRING), r.linhas = r.esperadas),
  ('tipo fora de Inbound, Mercado', CAST(r.tipo_invalido AS STRING), '0', r.tipo_invalido = 0),
  ('contagens nulas ou negativas', CAST(r.contagem_invalida AS STRING), '0', r.contagem_invalida = 0),
  ('linhas em que as partes não somam o total', CAST(r.partes_nao_somam AS STRING), '0', r.partes_nao_somam = 0),
  ('data fora do ano de ontem', CAST(r.data_fora AS STRING), '0', r.data_fora = 0),
  ('sábado ou domingo marcado como dia útil (PD2)', CAST(r.fim_de_semana_util AS STRING), '0', r.fim_de_semana_util = 0),
  ('dia × tipo com total diferente da gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)',
    IFNULL((SELECT STRING_AGG(FORMAT('%t %s: %d ≠ %d', data, tipo, tabela, diaria), ' | ' ORDER BY data, tipo LIMIT 10)
            FROM comparacao WHERE tabela != diaria), '0'),
    '0', (SELECT COUNTIF(tabela != diaria) = 0 FROM comparacao)),
  ('partes acima da talentos_ano (exclusivos | não exclusivos | sem talento)',
    FORMAT('%d de %d | %d de %d | %d de %d', r.ex, n.ex, r.nex, n.nex, r.sem, n.sem), 'cada uma ≤ o ano',
    r.ex <= n.ex AND r.nex <= n.nex AND r.sem <= n.sem),
  ('dias úteis no ano | feriados de seg a sex', FORMAT('%d | %d', CAST(r.dias_uteis AS INT64), CAST(r.feriados_seg_sex AS INT64)),
    'informativo', TRUE),
  ('pedidos em dia não útil (fim de semana ou feriado)', CAST(r.pedidos_fora_dia_util AS STRING), 'informativo', TRUE),
  ('Mercado por mês (exclusivos / não exclusivos / sem talento)',
    (SELECT STRING_AGG(FORMAT('%s: %d/%d/%d', FORMAT_DATE('%Y-%m', mes), e, ne, st), ' | ' ORDER BY mes)
     FROM (SELECT DATE_TRUNC(data, MONTH) AS mes, SUM(exclusivos) AS e, SUM(nao_exclusivos) AS ne, SUM(sem_talento) AS st
           FROM t WHERE tipo = 'Mercado' GROUP BY mes)), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 11 — TABELA gld_agenciamento_2026_previsao_lotes (uma linha por dia × recorte). Cria já com os dados de hoje.
-- ============================================================================================================

CREATE OR REPLACE TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_lotes`
(
  data DATE OPTIONS(description="Data de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), de 1º/jan até ontem; só dias com pedido no recorte. Com recorte, forma a chave"),
  recorte STRING OPTIONS(description="inbound, mercado, mercado_exclusivos ou mercado_nao_exclusivos (os recortes da previsão; os dois últimos são partes do mercado com exclusividade definida)"),
  pedidos INT64 OPTIONS(description="Pedidos do recorte no dia; igual ao total do dia na gld_agenciamento_2026_previsao_exclusividade_diaria"),
  em_lote INT64 OPTIONS(description="Pedidos que fazem parte de um lote: 3 ou mais pedidos do recorte com a mesma marca (ou prefixo [Marca] do nome) no mesmo dia"),
  avulsos INT64 OPTIONS(description="pedidos − em_lote (inclui os sem marca)"),
  lotes INT64 OPTIONS(description="Quantos lotes (marcas com 3 ou mais pedidos no recorte e no dia)"),
  _processado_em TIMESTAMP OPTIONS(description="Momento da execução")
)
CLUSTER BY data, recorte
OPTIONS(
  description="Pedidos do board 2026 por dia de entrada e recorte da previsão (inbound, mercado, mercado_exclusivos, mercado_nao_exclusivos), separados em pedidos em lote (3 ou mais do recorte com a mesma marca no mesmo dia) e avulsos, de 1º/jan até ontem; só dias com pedido. Pedidos de cada dia e recorte iguais à gld_agenciamento_2026_previsao_exclusividade_diaria. Diagnóstico do mês em andamento da previsão. Uma linha por dia × recorte. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_previsao_lotes.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "previsao-lotes")]
)
AS
-- gold_monday.gld_agenciamento_2026_previsao_lotes — pedidos do ano por dia e recorte da previsão (inbound, mercado,
-- mercado_exclusivos, mercado_nao_exclusivos), separados em pedidos em lote e avulsos. Board 2026.
-- Ficha: docs/tabelas/gld_agenciamento_2026_previsao_lotes.md.
-- Origem: contrato previsao_lotes da auditoria do PPD-AGENCIAMENTO-SLA (26/10/2026), que reproduz _sql_lotes de
-- ml/dados.py do site (S6, D56 item 3: diagnóstico do mês em andamento). Mesma população e regras de data e de
-- exclusividade da gld_agenciamento_2026_talentos_ano. Por dia (e não "4 meses até o dia N" como no site): quem lê soma
-- o período que quiser, inclusive até o mesmo dia de cada mês. Só dias com pedido no recorte.
WITH parametros AS (
  SELECT
    DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS fim,                    -- R4: até ontem
    DATE_TRUNC(DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY), YEAR) AS inicio
),

-- R3: calendário sem expediente, o mesmo da gld_agenciamento_entrada_diaria (copiado igual; serve à data estimada R2)
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

pedidos AS (
  SELECT
    -- R21: cadastro retroativo = data_de_entrada; senão a data de criação (R1)
    -- R2: sem criado_em = data_de_saida − 5 dias úteis (data estimada)
    COALESCE(
      IF(i.data_de_saida < DATE(i.criado_em) AND i.data_de_entrada <= i.data_de_saida, i.data_de_entrada,
         DATE(i.criado_em)),
      (SELECT ARRAY_AGG(d ORDER BY d DESC)[SAFE_OFFSET(4)]
       FROM UNNEST(GENERATE_DATE_ARRAY(DATE_SUB(i.data_de_saida, INTERVAL 21 DAY),
                                       DATE_SUB(i.data_de_saida, INTERVAL 1 DAY))) AS d
       WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias))) AS dia,
    i.talento,
    i.tipo_de_input,
    -- L1: marca da coluna; sem ela, o prefixo [Marca] do nome do projeto
    COALESCE(i.marca, REGEXP_EXTRACT(i.nome_projeto, r'^\[([^\]]+)\]')) AS marca,
    -- exclusividade NA DATA DO PEDIDO (silver, regras 53/56/60). Sem criado_em a silver deixa NULL (regra 63b);
    -- aqui vale a coluna de origem: talento escrito em talentos_exclusivos = exclusivo
    COALESCE(i.exclusivo, IF(i.criado_em IS NULL AND i.talentos_exclusivos IS NOT NULL, TRUE, NULL)) AS exclusivo
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens` i
  CROSS JOIN feriados f
  WHERE i.state = 'active'                                                   -- R5
),

recortes AS (
  -- L2: um pedido entra no recorte do seu tipo e, se for Mercado com exclusividade definida, também no recorte dela
  SELECT p.dia, p.marca, r AS recorte
  FROM pedidos p
  CROSS JOIN parametros pr
  CROSS JOIN UNNEST(ARRAY_CONCAT(
      IF(p.tipo_de_input = 'Inbound', ['inbound'], []),
      IF(p.tipo_de_input = 'Mercado', ['mercado'], []),
      IF(p.tipo_de_input = 'Mercado' AND p.exclusivo, ['mercado_exclusivos'], []),
      IF(p.tipo_de_input = 'Mercado' AND NOT p.exclusivo, ['mercado_nao_exclusivos'], []))) AS r
  WHERE p.dia BETWEEN pr.inicio AND pr.fim                                   -- R4: até ontem
),

-- L3: lote = 3 ou mais pedidos do recorte com a mesma marca no mesmo dia; sem marca, nunca é lote
grupos AS (
  SELECT recorte, dia, marca, COUNT(*) AS n
  FROM recortes
  GROUP BY recorte, dia, marca
)

SELECT
  dia AS data,
  recorte,
  SUM(n) AS pedidos,
  SUM(IF(marca IS NOT NULL AND n >= 3, n, 0)) AS em_lote,
  SUM(IF(marca IS NOT NULL AND n >= 3, 0, n)) AS avulsos,
  COUNTIF(marca IS NOT NULL AND n >= 3) AS lotes,
  CURRENT_TIMESTAMP() AS _processado_em
FROM grupos
GROUP BY data, recorte
;

-- BLOCO 12 — validação de gld_agenciamento_2026_previsao_lotes (confere contra: previsao_exclusividade_diaria)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_lotes`
),

e AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

-- os quatro recortes da exclusividade diária, só nos dias com pedido (a lotes não grava zero)
base AS (
  SELECT data, recorte, n
  FROM e,
    UNNEST([
      STRUCT(IF(tipo = 'Inbound', 'inbound', 'mercado') AS recorte, total AS n),
      STRUCT(IF(tipo = 'Mercado', 'mercado_exclusivos', NULL), IF(tipo = 'Mercado', exclusivos, 0)),
      STRUCT(IF(tipo = 'Mercado', 'mercado_nao_exclusivos', NULL), IF(tipo = 'Mercado', nao_exclusivos, 0))])
  WHERE recorte IS NOT NULL AND n > 0
),

comparacao AS (
  SELECT COUNT(*) AS diferentes
  FROM (SELECT data, recorte, pedidos FROM t) x
  FULL JOIN base b USING (data, recorte)
  WHERE x.pedidos IS DISTINCT FROM b.n
),

mercado AS (
  SELECT data, SUM(IF(recorte = 'mercado', pedidos, 0)) AS todos,
    SUM(IF(recorte IN ('mercado_exclusivos', 'mercado_nao_exclusivos'), pedidos, 0)) AS partes
  FROM t GROUP BY data
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', data, recorte)) AS chaves,
    COUNTIF(recorte NOT IN ('inbound', 'mercado', 'mercado_exclusivos', 'mercado_nao_exclusivos')) AS recorte_invalido,
    COUNTIF(pedidos <= 0 OR em_lote < 0 OR avulsos < 0 OR lotes < 0) AS contagem_invalida,
    COUNTIF(em_lote + avulsos != pedidos) AS nao_somam,
    COUNTIF(em_lote < 3 * lotes OR (lotes = 0) != (em_lote = 0)) AS lote_incoerente,
    COUNTIF(data NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia) AS data_fora
  FROM t, ontem o
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, comparacao c, UNNEST([
  STRUCT(
    'chave data × recorte única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('recorte fora de inbound, mercado, mercado_exclusivos, mercado_nao_exclusivos', CAST(r.recorte_invalido AS STRING),
    '0', r.recorte_invalido = 0),
  ('contagens negativas ou dia sem pedido', CAST(r.contagem_invalida AS STRING), '0', r.contagem_invalida = 0),
  ('em_lote + avulsos ≠ pedidos', CAST(r.nao_somam AS STRING), '0', r.nao_somam = 0),
  ('lotes incoerentes (cada lote tem 3 ou mais pedidos)', CAST(r.lote_incoerente AS STRING), '0', r.lote_incoerente = 0),
  ('data fora do ano de ontem', CAST(r.data_fora AS STRING), '0', r.data_fora = 0),
  ('dia × recorte com pedidos diferentes da gld_agenciamento_2026_previsao_exclusividade_diaria',
    CAST(c.diferentes AS STRING), '0', c.diferentes = 0),
  ('dias com mercado_exclusivos + mercado_nao_exclusivos acima do mercado',
    (SELECT CAST(COUNTIF(partes > todos) AS STRING) FROM mercado), '0', (SELECT COUNTIF(partes > todos) = 0 FROM mercado)),
  ('mês de ontem até ontem: pedidos = em lote + avulsos, por recorte',
    (SELECT STRING_AGG(FORMAT('%s: %d = %d + %d', recorte, p, l, a), ' | ' ORDER BY recorte)
     FROM (SELECT recorte, SUM(pedidos) p, SUM(em_lote) l, SUM(avulsos) a FROM t, ontem o
           WHERE data >= DATE_TRUNC(o.dia, MONTH) GROUP BY recorte)), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 13 — PERMISSÕES: escrita da conta do job (gold-agenciamento) em cada tabela nova.
-- Views não precisam. Recriar uma tabela pelo criar_ apaga esta permissão: rodar de novo.
-- ============================================================================================================

GRANT `roles/bigquery.dataEditor` ON TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano` TO "serviceAccount:gold-agenciamento@gglobo-viu-dados-hdg-prd.iam.gserviceaccount.com";
GRANT `roles/bigquery.dataEditor` ON TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ranking` TO "serviceAccount:gold-agenciamento@gglobo-viu-dados-hdg-prd.iam.gserviceaccount.com";
GRANT `roles/bigquery.dataEditor` ON TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status` TO "serviceAccount:gold-agenciamento@gglobo-viu-dados-hdg-prd.iam.gserviceaccount.com";
GRANT `roles/bigquery.dataEditor` ON TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria` TO "serviceAccount:gold-agenciamento@gglobo-viu-dados-hdg-prd.iam.gserviceaccount.com";
GRANT `roles/bigquery.dataEditor` ON TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_lotes` TO "serviceAccount:gold-agenciamento@gglobo-viu-dados-hdg-prd.iam.gserviceaccount.com";

-- ============================================================================================================
-- BLOCO 14 — VIEW gld_agenciamento_2026_previsao_exclusividade_mensal (uma linha por mês × tipo). Não guarda dados; sempre igual à base.
-- ============================================================================================================

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

-- BLOCO 15 — validação de gld_agenciamento_2026_previsao_exclusividade_mensal (confere contra: entrada_diaria, talentos_ano)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

a AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

-- total por mês × tipo nas duas tabelas
comparacao AS (
  SELECT COALESCE(x.mes, y.mes) AS mes, COALESCE(x.tipo, y.tipo) AS tipo, IFNULL(x.n, 0) AS tabela, IFNULL(y.n, 0) AS diaria
  FROM (SELECT mes, tipo, total AS n FROM t) x
  FULL JOIN (
    SELECT DATE_TRUNC(d.data, MONTH) AS mes, d.tipo_de_input AS tipo, SUM(d.quantidade + d.quantidade_estimada) AS n
    FROM d, ontem o
    WHERE d.tipo_de_input IN ('Inbound', 'Mercado') AND d.data BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia
    GROUP BY mes, tipo) y
  ON x.mes = y.mes AND x.tipo = y.tipo
),

ano AS (
  SELECT IFNULL(SUM(IF(categoria = 'Exclusivos', n, 0)), 0) AS ex,
    IFNULL(SUM(IF(categoria = 'Não exclusivos', n, 0)), 0) AS nex,
    IFNULL(SUM(IF(categoria = 'Sem talento', n, 0)), 0) AS sem
  FROM a
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, tipo)) AS chaves,
    COUNTIF(tipo NOT IN ('Inbound', 'Mercado')) AS tipo_invalido,
    COUNTIF(exclusivos < 0 OR nao_exclusivos < 0 OR sem_talento < 0 OR total < 0) AS contagem_invalida,
    COUNTIF(exclusivos + nao_exclusivos + sem_talento != total) AS partes_nao_somam,
    COUNTIF(mes NOT BETWEEN DATE_TRUNC(o.dia, YEAR) AND o.dia OR mes != DATE_TRUNC(mes, MONTH)) AS mes_fora,
    COUNTIF(completo != (LAST_DAY(mes) <= o.dia)) AS completo_errado,
    -- IFNULL: no começo de janeiro a tabela pode estar vazia
    IFNULL(SUM(exclusivos), 0) AS ex, IFNULL(SUM(nao_exclusivos), 0) AS nex, IFNULL(SUM(sem_talento), 0) AS sem,
    COUNTIF(mes < DATE_TRUNC(o.dia, MONTH)) AS fechadas,
    COUNTIF(mes = DATE_TRUNC(o.dia, MONTH)) AS correntes
  FROM t, ontem o
),

-- meses fechados do ano (janeiro até o mês anterior ao de ontem), nos dois tipos
esperado AS (
  SELECT 2 * DATE_DIFF(DATE_TRUNC(dia, MONTH), DATE_TRUNC(dia, YEAR), MONTH) AS fechadas FROM ontem
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, ano n, esperado e, UNNEST([
  STRUCT(
    'chave mês × tipo única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses fechados do ano nos dois tipos (sem buraco)', CAST(r.fechadas AS STRING),
    CAST(e.fechadas AS STRING), r.fechadas = e.fechadas),
  ('tipos sem linha no mês de ontem (começo de mês, ainda sem pedido)', CAST(2 - r.correntes AS STRING), 'aviso', TRUE),
  ('tipo fora de Inbound, Mercado', CAST(r.tipo_invalido AS STRING), '0', r.tipo_invalido = 0),
  ('contagens negativas', CAST(r.contagem_invalida AS STRING), '0', r.contagem_invalida = 0),
  ('linhas em que as partes não somam o total', CAST(r.partes_nao_somam AS STRING), '0', r.partes_nao_somam = 0),
  ('mês fora do ano de ontem ou que não é 1º dia', CAST(r.mes_fora AS STRING), '0', r.mes_fora = 0),
  ('completo diferente de "último dia do mês até ontem"', CAST(r.completo_errado AS STRING), '0', r.completo_errado = 0),
  ('mês × tipo com total diferente da diária (quantidade + quantidade_estimada)',
    IFNULL((SELECT STRING_AGG(FORMAT('%s %s: %d ≠ %d', FORMAT_DATE('%Y-%m', mes), tipo, tabela, diaria), ' | '
                              ORDER BY mes, tipo)
            FROM comparacao WHERE tabela != diaria), '0'),
    '0', (SELECT COUNTIF(tabela != diaria) = 0 FROM comparacao)),
  ('partes acima da talentos_ano (exclusivos | não exclusivos | sem talento)',
    FORMAT('%d de %d | %d de %d | %d de %d', r.ex, n.ex, r.nex, n.nex, r.sem, n.sem), 'cada uma ≤ o ano',
    r.ex <= n.ex AND r.nex <= n.nex AND r.sem <= n.sem),
  ('Mercado por mês (exclusivos / não exclusivos / sem talento)',
    (SELECT STRING_AGG(FORMAT('%s: %d/%d/%d', FORMAT_DATE('%Y-%m', mes), exclusivos, nao_exclusivos, sem_talento), ' | '
                       ORDER BY mes) FROM t WHERE tipo = 'Mercado'), 'informativo', TRUE),
  ('Inbound por mês (total)',
    (SELECT STRING_AGG(FORMAT('%s: %d', FORMAT_DATE('%Y-%m', mes), total), ' | ' ORDER BY mes) FROM t
     WHERE tipo = 'Inbound'), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 16 — VIEW gld_agenciamento_2026_previsao_exclusividade_mensal_inbound (uma linha por mês). Não guarda dados; sempre igual à base.
-- ============================================================================================================

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_inbound`
(
  mes OPTIONS(description="1º dia do mês de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), de janeiro até o mês de ontem; só Inbound. É a chave"),
  exclusivos OPTIONS(description="Pedidos com talento exclusivo na data do pedido"),
  nao_exclusivos OPTIONS(description="Pedidos com talento não exclusivo na data do pedido (inclui Squad de Talentos)"),
  sem_talento OPTIONS(description="Pedidos sem exclusividade definida na silver (sem talento)"),
  total OPTIONS(description="exclusivos + nao_exclusivos + sem_talento; igual às entradas de Inbound do mês na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  completo OPTIONS(description="TRUE = mês fechado; FALSE = mês de ontem, ainda parcial (não comparar com mês fechado)"),
  _processado_em OPTIONS(description="Momento da execução")
)
OPTIONS(
  description="Só Inbound da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio): pedidos do board 2026 por mês de entrada, divididos em exclusivos, não exclusivos e sem talento, de janeiro até ontem; completo separa os meses fechados do mês corrente. Uma linha por mês. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "previsao-exclusividade-mensal-inbound")]
)
AS
-- gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_inbound — só Inbound da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio).
-- Ficha: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md, seção "Derivações". Mesmas colunas da base, sem tipo (é sempre Inbound).
SELECT mes, exclusivos, nao_exclusivos, sem_talento, total, completo, _processado_em
FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal`
WHERE tipo = 'Inbound'
;

-- BLOCO 17 — validação de gld_agenciamento_2026_previsao_exclusividade_mensal_inbound (confere contra: previsao_exclusividade_mensal)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_inbound`
),

b AS (
  SELECT * EXCEPT (tipo) FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal` WHERE tipo = 'Inbound'
),

dif AS (
  SELECT COUNT(*) AS n FROM (
    (SELECT * EXCEPT (_processado_em) FROM t EXCEPT DISTINCT SELECT * EXCEPT (_processado_em) FROM b)
    UNION ALL
    (SELECT * EXCEPT (_processado_em) FROM b EXCEPT DISTINCT SELECT * EXCEPT (_processado_em) FROM t))
)

SELECT verificacao, resultado, esperado, ok
FROM dif, UNNEST([
  STRUCT(
    'linhas = base com tipo Inbound' AS verificacao,
    FORMAT('%d (base %d)', (SELECT COUNT(*) FROM t), (SELECT COUNT(*) FROM b)) AS resultado,
    'iguais' AS esperado,
    (SELECT COUNT(*) FROM t) = (SELECT COUNT(*) FROM b) AS ok),
  ('linhas diferentes da base', CAST(dif.n AS STRING), '0', dif.n = 0),
  ('total do ano (Inbound)', CAST((SELECT SUM(total) FROM t) AS STRING), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 18 — VIEW gld_agenciamento_2026_previsao_exclusividade_mensal_mercado (uma linha por mês). Não guarda dados; sempre igual à base.
-- ============================================================================================================

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

-- BLOCO 19 — validação de gld_agenciamento_2026_previsao_exclusividade_mensal_mercado (confere contra: previsao_exclusividade_mensal)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_mercado`
),

b AS (
  SELECT * EXCEPT (tipo) FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal` WHERE tipo = 'Mercado'
),

dif AS (
  SELECT COUNT(*) AS n FROM (
    (SELECT * EXCEPT (_processado_em) FROM t EXCEPT DISTINCT SELECT * EXCEPT (_processado_em) FROM b)
    UNION ALL
    (SELECT * EXCEPT (_processado_em) FROM b EXCEPT DISTINCT SELECT * EXCEPT (_processado_em) FROM t))
)

SELECT verificacao, resultado, esperado, ok
FROM dif, UNNEST([
  STRUCT(
    'linhas = base com tipo Mercado' AS verificacao,
    FORMAT('%d (base %d)', (SELECT COUNT(*) FROM t), (SELECT COUNT(*) FROM b)) AS resultado,
    'iguais' AS esperado,
    (SELECT COUNT(*) FROM t) = (SELECT COUNT(*) FROM b) AS ok),
  ('linhas diferentes da base', CAST(dif.n AS STRING), '0', dif.n = 0),
  ('total do ano (Mercado)', CAST((SELECT SUM(total) FROM t) AS STRING), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 20 — VIEW gld_agenciamento_2026_sla_entregas (uma linha por orçamento entregue). Não guarda dados; sempre igual à base.
-- ============================================================================================================

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas`
(
  projeto_id OPTIONS(description="Orçamento entregue (chave): tem passo com o cliente depois do passo 1"),
  mes OPTIONS(description="1º dia do mês da 1ª entrega (1ª entrada em Aguardando Feedback): o mês do SLA"),
  mes_entrada OPTIONS(description="1º dia do mês em que o orçamento entrou (passo 1)"),
  inicio OPTIONS(description="Entrada do passo 1 (o pedido)"),
  entregue_em OPTIONS(description="Entrada do 1º passo com o cliente (a 1ª entrega)"),
  exclusivo OPTIONS(description="Exclusividade do talento no passo 1 (Todos / Exclusivos / Não exclusivos do SLA)"),
  tipo_de_input OPTIONS(description="Tipo de input no passo 1"),
  pacote OPTIONS(description="Card de pacote/lote (nome começa por [Pacote); fica na base, só identificado"),
  h_trabalho OPTIONS(description="Horas de trabalho da equipe até a 1ª entrega, sem almoço: passos da fase equipe antes da entrega, sem o Retorno Marca"),
  h_fila OPTIONS(description="Parte de h_trabalho no status Entrada (espera na fila)"),
  h_elaboracao OPTIONS(description="Parte de h_trabalho nos status que começam por Em elaboração"),
  h_revisao OPTIONS(description="Parte de h_trabalho nos status que começam por Em revisão"),
  h_calendario OPTIONS(description="Horas corridas de calendário entre o pedido e a 1ª entrega"),
  dias_uteis OPTIONS(description="Dias úteis inteiros que o cliente esperou (pedido depois das 19h ou fora de dia útil conta do próximo dia útil)"),
  dias_uteis_fr OPTIONS(description="Dias úteis com fração: todas as horas sem almoço entre o pedido e a 1ª entrega ÷ 8 h"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_2026_sla_movimentos que a view lê")
)
OPTIONS(
  description="Um orçamento entregue por linha (view sobre a gld_agenciamento_2026_sla_movimentos): mês da 1ª entrega e o tempo até ela, em horas de trabalho da equipe sem almoço (total, fila, elaboração, revisão), horas de calendário e dias úteis inteiros e com fração. Base do SLA de entrega do site. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_2026_sla_entregas.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2026"), ("origem", "monday"), ("tipo", "sla-entregas")]
)
AS
-- gold_monday.gld_agenciamento_2026_sla_entregas (VIEW) — um orçamento entregue por linha: mês da 1ª entrega e o
-- tempo até ela (horas de trabalho da equipe sem almoço, por etapa, de calendário e dias úteis). Ficha:
-- docs/tabelas/gld_agenciamento_2026_sla_entregas.md. Base: gld_agenciamento_2026_sla_movimentos (as horas sem almoço
-- da R24). Reproduz entregas() de app/apresentacoes/gestao_orcamentos/sla/calculos.py do site (C1–C4, C9, C10, C14,
-- X6, J1), que deixa de recalcular o expediente. View: sempre igual à base, não entra no job.
WITH m AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

-- calendário sem expediente: o mesmo da R14 da gld_agenciamento_2026_sla_movimentos (copiado igual; serve aos dias úteis
-- inteiros da E5; as horas já vêm prontas da coluna sla_sem_almoco_horas, R24)
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

-- E1 (C4): 1ª entrega = 1º passo com o cliente (Aguardando Feedback); no passo 1 não é entrega (fica fora)
primeira AS (
  SELECT projeto_id, MIN(passo) AS passo_pronto FROM m WHERE fase = 'cliente' GROUP BY projeto_id
),

pronto AS (
  SELECT p.projeto_id, p.passo_pronto, x.entrada AS entregue_em
  FROM primeira p
  JOIN m x ON x.projeto_id = p.projeto_id AND x.passo = p.passo_pronto
  WHERE p.passo_pronto > 1
),

-- E2 (C2, C9, C14): horas sem almoço dos passos antes da 1ª entrega. Trabalho = fase equipe, sem o Retorno Marca
-- (espera da marca); fila = status Entrada; elaboração e revisão pelo começo do nome. E4: dias úteis com fração =
-- todas as horas sem almoço até a entrega (todas as fases) ÷ 8 h do dia útil
horas AS (
  SELECT
    x.projeto_id,
    SUM(IF(x.equipe, x.h, 0)) AS h_trabalho,
    SUM(IF(x.equipe AND x.status = 'Entrada', x.h, 0)) AS h_fila,
    SUM(IF(x.equipe AND STARTS_WITH(LOWER(x.status), 'em elabora'), x.h, 0)) AS h_elaboracao,
    SUM(IF(x.equipe AND STARTS_WITH(LOWER(x.status), 'em revis'), x.h, 0)) AS h_revisao,
    SUM(x.h) / 8 AS dias_uteis_fr
  FROM (
    SELECT m.projeto_id, m.status, IFNULL(m.sla_sem_almoco_horas, 0) AS h,
      m.fase = 'equipe' AND NOT IFNULL(STARTS_WITH(LOWER(m.status), 'em elaboração - retorno marca'), FALSE) AS equipe
    FROM m JOIN pronto p ON p.projeto_id = m.projeto_id AND m.passo < p.passo_pronto) x
  GROUP BY x.projeto_id
),

base AS (
  SELECT
    p.projeto_id, a.entrada AS inicio, p.entregue_em, a.exclusivo, a.tipo_de_input, a.nome_projeto,
    -- E5 (C3b): dias úteis inteiros que o cliente esperou; pedido depois das 19h ou fora de dia útil conta do próximo
    IF(EXTRACT(HOUR FROM a.entrada) >= 19 OR EXTRACT(DAYOFWEEK FROM a.entrada) IN (1, 7)
         OR DATE(a.entrada) IN UNNEST(f.dias),
       (SELECT MIN(d) FROM UNNEST(GENERATE_DATE_ARRAY(DATE_ADD(DATE(a.entrada), INTERVAL 1 DAY),
                                                      DATE_ADD(DATE(a.entrada), INTERVAL 30 DAY))) AS d
        WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(f.dias)),
       DATE(a.entrada)) AS conta_de,
    f.dias
  FROM pronto p
  JOIN m a ON a.projeto_id = p.projeto_id AND a.passo = 1
  CROSS JOIN feriados f
)

SELECT
  b.projeto_id,
  DATE_TRUNC(DATE(b.entregue_em), MONTH) AS mes,                    -- E1 (C4): mês da 1ª entrega
  DATE_TRUNC(DATE(b.inicio), MONTH) AS mes_entrada,
  b.inicio,
  b.entregue_em,
  b.exclusivo,                                                      -- C10: do passo 1
  b.tipo_de_input,                                                  -- J1: do passo 1
  STARTS_WITH(TRIM(IFNULL(b.nome_projeto, '')), '[Pacote') AS pacote,  -- X6: card de pacote, só identificado
  h.h_trabalho,
  h.h_fila,
  h.h_elaboracao,
  h.h_revisao,
  DATETIME_DIFF(b.entregue_em, b.inicio, MICROSECOND) / 3600000000 AS h_calendario,  -- E3 (C3)
  (SELECT COUNT(*) FROM UNNEST(GENERATE_DATE_ARRAY(b.conta_de, DATE_SUB(DATE(b.entregue_em), INTERVAL 1 DAY))) AS d
   WHERE EXTRACT(DAYOFWEEK FROM d) BETWEEN 2 AND 6 AND d NOT IN UNNEST(b.dias)) AS dias_uteis,
  h.dias_uteis_fr,
  (SELECT MAX(_processado_em) FROM m) AS _processado_em
FROM base b
JOIN horas h USING (projeto_id)
;

-- BLOCO 21 — validação de gld_agenciamento_2026_sla_entregas (confere contra: sla_movimentos)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas`
),

m AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

-- E1 na base: projetos cujo 1º passo com o cliente vem depois do passo 1
esperados AS (
  SELECT projeto_id FROM m WHERE fase = 'cliente' GROUP BY projeto_id HAVING MIN(passo) > 1
),

ontem AS (
  SELECT DATE_SUB(CURRENT_DATE('America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT projeto_id) AS chaves,
    COUNTIF(entregue_em < inicio OR inicio IS NULL OR entregue_em IS NULL) AS datas_invalidas,
    COUNTIF(mes != DATE_TRUNC(DATE(entregue_em), MONTH) OR mes_entrada != DATE_TRUNC(DATE(inicio), MONTH)) AS mes_errado,
    COUNTIF(h_trabalho IS NULL OR h_fila IS NULL OR h_elaboracao IS NULL OR h_revisao IS NULL OR h_calendario IS NULL
            OR h_trabalho < 0 OR h_fila < 0 OR h_elaboracao < 0 OR h_revisao < 0 OR dias_uteis < 0
            OR dias_uteis_fr < 0) AS horas_invalidas,
    COUNTIF(h_fila + h_elaboracao + h_revisao > h_trabalho + 1e-6) AS partes_acima,
    IFNULL(SUM(h_trabalho), 0) AS h_total,
    COUNTIF(mes = DATE_TRUNC(o.dia, MONTH)) AS no_mes,
    ROUND(AVG(IF(mes = DATE_TRUNC(o.dia, MONTH), h_trabalho, NULL)), 1) AS h_media_mes
  FROM t, ontem o
),

populacao AS (
  SELECT COUNT(*) AS diferentes
  FROM (SELECT projeto_id FROM t) x FULL JOIN esperados e USING (projeto_id)
  WHERE x.projeto_id IS NULL OR e.projeto_id IS NULL
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, populacao p, UNNEST([
  STRUCT(
    'chave projeto_id única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('projetos diferentes da base (1º passo com o cliente depois do passo 1, E1)', CAST(p.diferentes AS STRING), '0',
    p.diferentes = 0),
  ('entrega antes do pedido ou data vazia', CAST(r.datas_invalidas AS STRING), '0', r.datas_invalidas = 0),
  ('mes ou mes_entrada diferente do mês das datas', CAST(r.mes_errado AS STRING), '0', r.mes_errado = 0),
  ('horas ou dias nulos ou negativos', CAST(r.horas_invalidas AS STRING), '0', r.horas_invalidas = 0),
  ('fila + elaboração + revisão acima do trabalho (E2)', CAST(r.partes_acima AS STRING), '0', r.partes_acima = 0),
  ('horas sem almoço ainda não calculadas (R24 vazia na SLA)', CAST(IF(r.linhas > 0 AND r.h_total = 0, 1, 0) AS STRING),
    'aviso', TRUE),
  ('entregas no mês de ontem | média de horas de trabalho', FORMAT('%d | %t', r.no_mes, r.h_media_mes), 'informativo',
    TRUE)
]);

-- ============================================================================================================
-- BLOCO 22 — VIEW gld_agenciamento_2026_sla_entregas_status (uma linha por orçamento × status). Não guarda dados; sempre igual à base.
-- ============================================================================================================

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

-- BLOCO 23 — validação de gld_agenciamento_2026_sla_entregas_status (confere contra: sla_entregas)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas_status`
),

e AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_entregas`
),

soma AS (
  SELECT projeto_id, SUM(IFNULL(h, 0)) AS h FROM t GROUP BY projeto_id
),

comparacao AS (
  SELECT
    COUNTIF(e.projeto_id IS NULL) AS fora_das_entregas,
    COUNTIF(ABS(IFNULL(s.h, 0) - IFNULL(e.h_trabalho, 0)) > 1e-6) AS soma_diferente
  FROM soma s FULL JOIN e USING (projeto_id)
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', projeto_id, status)) AS chaves,
    COUNTIF(status IS NULL OR h < 0) AS invalidas,
    COUNTIF(h IS NULL) AS h_nulo,
    COUNT(DISTINCT projeto_id) AS projetos,
    COUNTIF(STARTS_WITH(LOWER(status), 'em elaboração - retorno marca')) AS retorno_marca
  FROM t
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, comparacao c, UNNEST([
  STRUCT(
    'chave projeto_id × status única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('status vazio ou horas negativas', CAST(r.invalidas AS STRING), '0', r.invalidas = 0),
  ('Em elaboração - Retorno Marca presente (espera da marca, fora do trabalho)', CAST(r.retorno_marca AS STRING), '0',
    r.retorno_marca = 0),
  ('orçamentos fora da gld_agenciamento_2026_sla_entregas', CAST(c.fora_das_entregas AS STRING), '0',
    c.fora_das_entregas = 0),
  ('orçamentos com soma por status ≠ h_trabalho da gld_agenciamento_2026_sla_entregas', CAST(c.soma_diferente AS STRING),
    '0', c.soma_diferente = 0),
  ('horas sem almoço ainda não calculadas (R24 vazia na SLA)', CAST(r.h_nulo AS STRING), 'aviso', TRUE),
  ('orçamentos com horas por status', CAST(r.projetos AS STRING), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 24 — VIEW gld_agenciamento_fila_mensal (uma linha por mês × mês de entrada). Não guarda dados; sempre igual à base.
-- ============================================================================================================

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

-- BLOCO 25 — validação de gld_agenciamento_fila_mensal (confere contra: fluxo_mensal)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fila_mensal`
),

f AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
),

ultimo AS (
  SELECT DATE_TRUNC(DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY), MONTH) AS mes FROM f
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, mes_entrada)) AS chaves,
    COUNT(DISTINCT mes) AS meses,
    COUNTIF(mes_entrada > mes OR mes != DATE_TRUNC(mes, MONTH) OR mes_entrada != DATE_TRUNC(mes_entrada, MONTH))
      AS datas_invalidas,
    COUNTIF(novos < 0 OR represados < 0 OR entregues < 0 OR nao_seguiram < 0 OR seguem < 0) AS negativos,
    COUNTIF(do_ano AND novos + represados - entregues - nao_seguiram != seguem) AS nao_fecha,
    COUNTIF(novos > 0 AND mes != mes_entrada) AS novos_fora_da_safra,
    COUNTIF(NOT do_ano AND (novos + represados + nao_seguiram + seguem > 0 OR entregues = 0)) AS fora_do_ano_invalido,
    SUM(entregues) AS entregues
  FROM t
),

passagem AS (
  SELECT COUNTIF(a.seguem != b.represados) AS diferentes
  FROM t a
  JOIN t b ON b.mes_entrada = a.mes_entrada AND b.mes = DATE_ADD(a.mes, INTERVAL 1 MONTH)
  WHERE a.do_ano AND b.do_ano
),

fluxo AS (
  SELECT SUM(quantidade) AS entregues
  FROM f, ultimo u
  WHERE evento = 'entregue' AND mes_evento BETWEEN DATE '2024-10-01' AND u.mes
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, passagem p, fluxo x, ultimo u, UNNEST([
  STRUCT(
    'chave mês × mês de entrada única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses de 2024-10 até o mês de ontem, sem buraco', CAST(r.meses AS STRING),
    CAST(DATE_DIFF(u.mes, DATE '2024-10-01', MONTH) + 1 AS STRING),
    r.meses = DATE_DIFF(u.mes, DATE '2024-10-01', MONTH) + 1),
  ('mês de entrada depois do mês ou datas que não são 1º dia', CAST(r.datas_invalidas AS STRING), '0',
    r.datas_invalidas = 0),
  ('contagens negativas', CAST(r.negativos AS STRING), '0', r.negativos = 0),
  ('safras do ano em que novos + represados − entregues − não seguiram ≠ seguem', CAST(r.nao_fecha AS STRING), '0',
    r.nao_fecha = 0),
  ('o que segue no fim do mês ≠ represado no mês seguinte (mesma safra, mesmo ano)', CAST(p.diferentes AS STRING), '0',
    p.diferentes = 0),
  ('novos fora do mês de entrada', CAST(r.novos_fora_da_safra AS STRING), '0', r.novos_fora_da_safra = 0),
  ('safras de anos anteriores com fila ou sem entrega (FM1)', CAST(r.fora_do_ano_invalido AS STRING), '0',
    r.fora_do_ano_invalido = 0),
  ('entregas = entregue do fluxo mensal com mês do evento de 2024-10 até o mês de ontem', CAST(r.entregues AS STRING),
    CAST(x.entregues AS STRING), r.entregues = x.entregues),
  ('mês de ontem: novos | represados | entregues | não seguiram | seguem',
    (SELECT FORMAT('%d | %d | %d | %d | %d', SUM(novos), SUM(represados), SUM(entregues), SUM(nao_seguiram), SUM(seguem))
     FROM t WHERE mes = u.mes), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 26 — VIEW gld_agenciamento_atendimento_mensal (uma linha por mês). Não guarda dados; sempre igual à base.
-- ============================================================================================================

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

-- BLOCO 27 — validação de gld_agenciamento_atendimento_mensal (confere contra: fila_mensal, entrada_diaria)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_atendimento_mensal`
),

fila AS (
  SELECT mes, SUM(seguem) AS seguem
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fila_mensal`
  WHERE do_ano
  GROUP BY mes
),

ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

contas AS (
  SELECT *,
    LAG(ficou) OVER (PARTITION BY EXTRACT(YEAR FROM mes) ORDER BY mes) AS ficou_antes
  FROM t
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT mes) AS chaves,
    COUNTIF(entradas < 0 OR entregues < 0 OR sem_entrega < 0 OR sem_entrega_sem_data < 0 OR externos < 0
            OR sem_entrega_sem_data > sem_entrega) AS negativos,
    COUNTIF(respondidos != entregues + sem_entrega OR para_atender != veio + entradas
            OR ficou != para_atender - respondidos OR dependia != para_atender - externos) AS contas_erradas,
    COUNTIF(veio != IFNULL(ficou_antes, 0)) AS veio_errado,
    COUNTIF(EXTRACT(MONTH FROM mes) = 1 AND veio != 0) AS janeiro_com_fila,
    COUNTIF(externos > sem_entrega OR (NOT status_confere AND externos != 0)) AS externos_invalidos,
    COUNTIF(completo != (LAST_DAY(mes) <= o.dia)) AS completo_errado,
    COUNTIF(EXTRACT(YEAR FROM mes) = EXTRACT(YEAR FROM o.dia) AND NOT status_confere) AS ano_sem_status
  FROM contas, ontem o
),

contra_fila AS (
  SELECT COUNTIF(t.ficou != IFNULL(f.seguem, 0)) AS diferentes,
    STRING_AGG(IF(t.ficou != IFNULL(f.seguem, 0), FORMAT('%s: %d ≠ %d', FORMAT_DATE('%Y-%m', t.mes), t.ficou,
      IFNULL(f.seguem, 0)), NULL), ' | ' ORDER BY t.mes) AS texto
  FROM t
  CROSS JOIN ontem o
  LEFT JOIN fila f ON f.mes = t.mes
  WHERE EXTRACT(YEAR FROM t.mes) = EXTRACT(YEAR FROM o.dia)
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, contra_fila c, ontem o, UNNEST([
  STRUCT(
    'chave mês única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses de 2025-01 até o mês de ontem, sem buraco', CAST(r.linhas AS STRING),
    CAST(DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2025-01-01', MONTH) + 1 AS STRING),
    r.linhas = DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2025-01-01', MONTH) + 1),
  ('contagens negativas ou sem data acima das saídas sem entrega', CAST(r.negativos AS STRING), '0', r.negativos = 0),
  ('contas do mês (respondidos, para atender, ficou, dependia) que não fecham', CAST(r.contas_erradas AS STRING), '0',
    r.contas_erradas = 0),
  ('veio ≠ o que ficou no mês anterior do mesmo ano', CAST(r.veio_errado AS STRING), '0', r.veio_errado = 0),
  ('janeiro com fila vinda do ano anterior (AM1)', CAST(r.janeiro_com_fila AS STRING), '0', r.janeiro_com_fila = 0),
  ('externos acima das saídas sem entrega ou sem a composição conferida (AM3)', CAST(r.externos_invalidos AS STRING), '0',
    r.externos_invalidos = 0),
  ('completo errado (só o mês de ontem fica parcial)', CAST(r.completo_errado AS STRING), '0', r.completo_errado = 0),
  ('meses do ano de ontem sem a composição por status conferida', CAST(r.ano_sem_status AS STRING), '0',
    r.ano_sem_status = 0),
  ('ano de ontem: ficou ≠ seguem da gld_agenciamento_fila_mensal', IFNULL(c.texto, '0'), '0', c.diferentes = 0),
  ('mês de ontem: entradas | entregues | sem entrega | ficou | externos',
    (SELECT FORMAT('%d | %d | %d | %d | %d', entradas, entregues, sem_entrega, ficou, externos)
     FROM t WHERE mes = DATE_TRUNC(o.dia, MONTH)), 'informativo', TRUE)
]);

-- ============================================================================================================
-- BLOCO 28 — VIEW gld_agenciamento_previsao_mensal (uma linha por mês × tipo). Não guarda dados; sempre igual à base.
-- ============================================================================================================

CREATE OR REPLACE VIEW `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_previsao_mensal`
(
  mes OPTIONS(description="1º dia do mês de entrada, de 2024-10 até o mês de ontem. Com tipo, forma a chave"),
  tipo OPTIONS(description="Tipo de input: Inbound ou Mercado"),
  pedidos OPTIONS(description="quantidade + quantidade_estimada da gld_agenciamento_entrada_diaria no mês"),
  estimados OPTIONS(description="Dos pedidos, quantos com data estimada"),
  completo OPTIONS(description="TRUE = mês fechado; FALSE = mês de ontem, parcial"),
  dados_ate OPTIONS(description="Ontem: último dia da carga (véspera do _processado_em, em São Paulo)"),
  _processado_em OPTIONS(description="Execução da gld_agenciamento_entrada_diaria que a view lê")
)
OPTIONS(
  description="Pedidos por mês de entrada e tipo de input (Inbound, Mercado) desde 2024-10 (view sobre a gld_agenciamento_entrada_diaria, soma por mês); completo separa os meses fechados do mês de ontem. Séries longas da previsão de demanda. Sempre igual à base. Regras: docs/tabelas/gld_agenciamento_previsao_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)",
  labels=[("projeto", "ppd-golden-agenciamento-monday"), ("camada", "gold"), ("board", "agenciamento-2024-2026"), ("origem", "monday"), ("tipo", "previsao-mensal")]
)
AS
-- gold_monday.gld_agenciamento_previsao_mensal (VIEW) — pedidos por mês de entrada e tipo de input (Inbound, Mercado),
-- de 2024-10 até o mês de ontem: as séries longas da previsão de demanda (S1 Inbound, S2 Mercado). Ficha:
-- docs/tabelas/gld_agenciamento_previsao_mensal.md. Base: gld_agenciamento_entrada_diaria (soma por mês, sem regra
-- própria). Reproduz SQL_SERIE de ml/dados.py do site. View: sempre igual à base, não entra no job.
-- completo = o mês terminou até ontem (véspera da carga, em São Paulo); o mês de ontem fica FALSE, ainda parcial.
WITH e AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia, MAX(_processado_em) AS carga
  FROM e
)

SELECT
  DATE_TRUNC(e.data, MONTH) AS mes,
  e.tipo_de_input AS tipo,
  SUM(e.quantidade + e.quantidade_estimada) AS pedidos,
  SUM(e.quantidade_estimada) AS estimados,
  LAST_DAY(MIN(e.data)) <= ANY_VALUE(o.dia) AS completo,
  ANY_VALUE(o.dia) AS dados_ate,
  ANY_VALUE(o.carga) AS _processado_em
FROM e, ontem o
WHERE e.tipo_de_input IN ('Inbound', 'Mercado') AND e.data <= o.dia
GROUP BY mes, tipo
;

-- BLOCO 29 — validação de gld_agenciamento_previsao_mensal (confere contra: entrada_diaria, previsao_exclusividade_diaria)

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_previsao_mensal`
),

d AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_entrada_diaria`
),

x AS (
  SELECT DATE_TRUNC(data, MONTH) AS mes, tipo, SUM(total) AS n
  FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
  GROUP BY mes, tipo
),

ontem AS (
  SELECT DATE_SUB(DATE(MAX(_processado_em), 'America/Sao_Paulo'), INTERVAL 1 DAY) AS dia FROM d
),

resumo AS (
  SELECT
    COUNT(*) AS linhas,
    COUNT(DISTINCT FORMAT('%t|%t', mes, tipo)) AS chaves,
    COUNTIF(tipo NOT IN ('Inbound', 'Mercado')) AS tipo_invalido,
    COUNTIF(pedidos < 0 OR estimados < 0 OR estimados > pedidos) AS contagem_invalida,
    COUNTIF(completo != (LAST_DAY(mes) <= o.dia) OR dados_ate != o.dia) AS completo_errado,
    SUM(pedidos) AS pedidos
  FROM t, ontem o
),

diaria AS (
  SELECT SUM(d.quantidade + d.quantidade_estimada) AS pedidos
  FROM d, ontem o
  WHERE d.tipo_de_input IN ('Inbound', 'Mercado') AND d.data <= o.dia
),

ano AS (
  SELECT COUNT(*) AS diferentes
  FROM (SELECT t.mes, t.tipo, t.pedidos FROM t, ontem o WHERE EXTRACT(YEAR FROM t.mes) = EXTRACT(YEAR FROM o.dia)) a
  FULL JOIN x b USING (mes, tipo)
  WHERE a.pedidos IS DISTINCT FROM b.n
)

SELECT verificacao, resultado, esperado, ok
FROM resumo r, diaria e, ano n, ontem o, UNNEST([
  STRUCT(
    'chave mês × tipo única' AS verificacao,
    FORMAT('%d linhas, %d chaves', r.linhas, r.chaves) AS resultado,
    'linhas = chaves' AS esperado,
    r.linhas = r.chaves AS ok),
  ('meses de 2024-10 até o mês de ontem, nos dois tipos', CAST(r.linhas AS STRING),
    CAST(2 * (DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2024-10-01', MONTH) + 1) AS STRING),
    r.linhas = 2 * (DATE_DIFF(DATE_TRUNC(o.dia, MONTH), DATE '2024-10-01', MONTH) + 1)),
  ('tipo fora de Inbound, Mercado', CAST(r.tipo_invalido AS STRING), '0', r.tipo_invalido = 0),
  ('contagens negativas ou estimados acima dos pedidos', CAST(r.contagem_invalida AS STRING), '0',
    r.contagem_invalida = 0),
  ('completo ou dados_ate errados (só o mês de ontem fica parcial)', CAST(r.completo_errado AS STRING), '0',
    r.completo_errado = 0),
  ('total = entradas Inbound + Mercado da gld_agenciamento_entrada_diaria até ontem', CAST(r.pedidos AS STRING),
    CAST(e.pedidos AS STRING), r.pedidos = e.pedidos),
  ('ano de ontem: mês × tipo ≠ gld_agenciamento_2026_previsao_exclusividade_diaria', CAST(n.diferentes AS STRING), '0',
    n.diferentes = 0),
  ('mês de ontem (Inbound | Mercado)',
    (SELECT STRING_AGG(CAST(pedidos AS STRING), ' | ' ORDER BY tipo) FROM t WHERE mes = DATE_TRUNC(o.dia, MONTH)),
    'informativo', TRUE)
]);

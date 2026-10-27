-- Validação de gold_monday.gld_agenciamento_2026_talentos_ano (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE; "informativo" vai ao log do job.
-- Confere a população contra a gld_agenciamento_entrada_diaria (mesmas regras de data, boards 2024–2026): os pedidos
-- do ano até ontem precisam ser os mesmos. No job, a diária vem antes em TABELAS e a conferência lê o cálculo dela da
-- mesma execução.
-- Referência de 26/10/2026 (informativo): 3.451 exclusivos + 1.980 não exclusivos + 125 sem talento = 5.556.
-- Virada do ano: nos primeiros dias de janeiro o ano pode não ter pedido; tabela vazia em janeiro é aceita (aviso).

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
])

-- Validação de gold_monday.gld_agenciamento_2026_sla_movimentos (só leitura).
-- Rodar depois de cada criação/atualização. Toda linha deve sair com ok = TRUE.
-- Referência do ensaio de 21/10/2026: 14.776 linhas, 3.095 projetos.
-- 22/10/2026: + entrada preenchida (R23), tempo dos passos concluídos e status repetido em sequência (R9 depois de R10).

WITH t AS (
  SELECT * FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
),

itens AS (
  SELECT projeto_id, status
  FROM `gglobo-viu-dados-hdg-prd.silver_monday.slv_agenciamento_2026_itens`
),

ultimo AS (
  SELECT projeto_id, ARRAY_AGG(status ORDER BY passo DESC LIMIT 1)[OFFSET(0)] AS status, MAX(passo) AS passos,
    COUNT(*) AS linhas
  FROM t
  GROUP BY projeto_id
)

SELECT verificacao, resultado, esperado, ok
FROM UNNEST([
  STRUCT(
    'chave projeto_id + passo única' AS verificacao,
    CAST((SELECT COUNT(*) - COUNT(DISTINCT FORMAT('%s-%d', projeto_id, passo)) FROM t) AS STRING) AS resultado,
    '0' AS esperado,
    (SELECT COUNT(*) = COUNT(DISTINCT FORMAT('%s-%d', projeto_id, passo)) FROM t) AS ok),
  ('passos de 1 a N sem buraco',
    CAST((SELECT COUNTIF(passos != linhas) FROM ultimo) AS STRING), '0',
    (SELECT COUNTIF(passos != linhas) = 0 FROM ultimo)),
  ('todo projeto começa em Entrada',
    CAST((SELECT COUNTIF(passo = 1 AND status != 'Entrada') FROM t) AS STRING), '0',
    (SELECT COUNTIF(passo = 1 AND status != 'Entrada') = 0 FROM t)),
  ('último passo = status atual da silver',
    CAST((SELECT COUNTIF(u.status != i.status) FROM ultimo u JOIN itens i USING (projeto_id)) AS STRING), '0',
    (SELECT COUNTIF(u.status != i.status) = 0 FROM ultimo u JOIN itens i USING (projeto_id))),
  ('status_atual igual em todas as linhas do projeto',
    CAST((SELECT COUNT(*) FROM (SELECT projeto_id FROM t GROUP BY projeto_id HAVING COUNT(DISTINCT status_atual) > 1)) AS STRING), '0',
    (SELECT COUNT(*) = 0 FROM (SELECT projeto_id FROM t GROUP BY projeto_id HAVING COUNT(DISTINCT status_atual) > 1))),
  ('só o último passo sem saída',
    CAST((SELECT COUNTIF((saida IS NULL) != (passo = u.passos)) FROM t JOIN ultimo u USING (projeto_id)) AS STRING), '0',
    (SELECT COUNTIF((saida IS NULL) != (passo = u.passos)) = 0 FROM t JOIN ultimo u USING (projeto_id))),
  ('entrada sempre preenchida (R23)',
    CAST((SELECT COUNTIF(entrada IS NULL) FROM t) AS STRING), '0',
    (SELECT COUNTIF(entrada IS NULL) = 0 FROM t)),
  ('passo concluído com tempo corrido e útil preenchidos',
    CAST((SELECT COUNTIF(saida IS NOT NULL AND (sla_corrido_horas IS NULL OR sla_util_horas IS NULL)) FROM t) AS STRING), '0',
    (SELECT COUNTIF(saida IS NOT NULL AND (sla_corrido_horas IS NULL OR sla_util_horas IS NULL)) = 0 FROM t)),
  ('passos seguidos com o mesmo status (R9 depois de R10)',
    CAST((SELECT COUNT(*) FROM (SELECT status, LAG(status) OVER (PARTITION BY projeto_id ORDER BY passo) AS anterior FROM t)
          WHERE status = anterior) AS STRING), '0',
    (SELECT COUNT(*) = 0 FROM (SELECT status, LAG(status) OVER (PARTITION BY projeto_id ORDER BY passo) AS anterior FROM t)
     WHERE status = anterior)),
  ('saída nunca antes da entrada',
    CAST((SELECT COUNTIF(saida < entrada) FROM t) AS STRING), '0',
    (SELECT COUNTIF(saida < entrada) = 0 FROM t)),
  ('útil nunca maior que o corrido e sem negativos',
    CAST((SELECT COUNTIF(sla_util_horas > sla_corrido_horas OR sla_util_horas < 0 OR sla_corrido_horas < 0) FROM t) AS STRING), '0',
    (SELECT COUNTIF(sla_util_horas > sla_corrido_horas OR sla_util_horas < 0 OR sla_corrido_horas < 0) = 0 FROM t)),
  ('hora extra nunca maior que o corrido',
    CAST((SELECT COUNTIF(hora_extra_horas > sla_corrido_horas + 0.01 OR hora_extra_horas < 0) FROM t) AS STRING), '0',
    (SELECT COUNTIF(hora_extra_horas > sla_corrido_horas + 0.01 OR hora_extra_horas < 0) = 0 FROM t)),
  ('em aberto só no último passo e fora de fechamento',
    CAST((SELECT COUNTIF(em_aberto AND (saida IS NOT NULL OR fase = 'fechamento')) FROM t) AS STRING), '0',
    (SELECT COUNTIF(em_aberto AND (saida IS NOT NULL OR fase = 'fechamento')) = 0 FROM t)),
  ('alerta só com o cliente em aberto',
    CAST((SELECT COUNTIF(alerta AND NOT (em_aberto AND fase = 'cliente')) FROM t) AS STRING), '0',
    (SELECT COUNTIF(alerta AND NOT (em_aberto AND fase = 'cliente')) = 0 FROM t)),
  ('fase preenchida e conhecida',
    CAST((SELECT COUNTIF(fase IS NULL OR fase NOT IN ('equipe', 'cliente', 'standby', 'fechamento')) FROM t) AS STRING), '0',
    (SELECT COUNTIF(fase IS NULL OR fase NOT IN ('equipe', 'cliente', 'standby', 'fechamento')) = 0 FROM t)),
  ('orçamento e link sempre preenchidos',
    CAST((SELECT COUNTIF(orcamento IS NULL OR link_projeto IS NULL) FROM t) AS STRING), '0',
    (SELECT COUNTIF(orcamento IS NULL OR link_projeto IS NULL) = 0 FROM t)),
  ('uma execução só (_processado_em único)',
    CAST((SELECT COUNT(DISTINCT _processado_em) FROM t) AS STRING), '1',
    (SELECT COUNT(DISTINCT _processado_em) = 1 FROM t)),
  -- volume: informativo (o recorte muda: um projeto que volta de Aguardando Feedback para a equipe sai e depois volta)
  ('volume: projetos (ensaio 21/10/2026 = 3.095)',
    CAST((SELECT COUNT(DISTINCT projeto_id) FROM t) AS STRING), 'perto de 3.095 e crescendo',
    (SELECT COUNT(DISTINCT projeto_id) > 0 FROM t)),
  ('volume: linhas (ensaio 21/10/2026 = 14.776)',
    CAST((SELECT COUNT(*) FROM t) AS STRING), 'perto de 14.776 e crescendo',
    (SELECT COUNT(*) > 0 FROM t))
])

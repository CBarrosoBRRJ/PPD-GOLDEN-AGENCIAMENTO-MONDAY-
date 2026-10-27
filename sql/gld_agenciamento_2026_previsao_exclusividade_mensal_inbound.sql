-- gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_inbound — só Inbound da gld_agenciamento_2026_previsao_exclusividade_mensal (view, sem cálculo próprio).
-- Ficha: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md, seção "Derivações". Mesmas colunas da base, sem tipo (é sempre Inbound).
SELECT mes, exclusivos, nao_exclusivos, sem_talento, total, completo, _processado_em
FROM `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal`
WHERE tipo = 'Inbound'

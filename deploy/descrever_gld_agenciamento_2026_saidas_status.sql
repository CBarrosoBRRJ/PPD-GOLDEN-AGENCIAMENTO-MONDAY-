-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_2026_saidas_status.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status` SET OPTIONS(description="Saídas sem entrega do board 2026 por mês do evento e status final (Declinado*, Standby, Encerrado), para os cards que entraram no ano (1º/jan até ontem): a composição do evento nao_seguiu da gld_agenciamento_fluxo_mensal, que não guarda o status. Mesmas regras do fluxo; sem data no log, mês de entrada. Uma linha por mês × status. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_saidas_status.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_saidas_status`
  ALTER COLUMN mes SET OPTIONS(description="1º dia do mês do evento: mês em que o card chegou ao status final, pela última entrada nele no log; nunca antes do mês de entrada; sem data no log = mês de entrada. Com status, forma a chave"),
  ALTER COLUMN status SET OPTIONS(description="Status atual do board que encerrou o card sem entrega: Declinado (e variações que começam por Declinado), Standby ou Encerrado"),
  ALTER COLUMN n SET OPTIONS(description="Cards que entraram no ano (1º/jan até ontem) e saíram sem entrega com esse status nesse mês. Soma do mês = nao_seguiu do mês na gld_agenciamento_fluxo_mensal (safra do ano)"),
  ALTER COLUMN sem_data SET OPTIONS(description="Dos n, quantos não têm a chegada ao status no log (contados no mês de entrada; no fluxo ficam com mes_evento NULL)"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução");

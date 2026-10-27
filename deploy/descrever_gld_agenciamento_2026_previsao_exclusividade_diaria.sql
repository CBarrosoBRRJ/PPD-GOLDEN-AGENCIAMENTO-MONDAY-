-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_2026_previsao_exclusividade_diaria.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria` SET OPTIONS(description="Pedidos do board 2026 por dia de entrada e tipo de input (Inbound, Mercado), divididos em exclusivos, não exclusivos e sem talento (exclusividade na data do pedido), todo dia de 1º/jan até ontem, com zero quando não há pedido; dia_util marca seg–sex fora dos feriados. O total de cada dia e tipo é igual às entradas da gld_agenciamento_entrada_diaria. Base das séries da previsão de demanda (a mensal é view sobre esta). Uma linha por dia × tipo. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_previsao_exclusividade_diaria.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`
  ALTER COLUMN data SET OPTIONS(description="Dia de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), todo dia de 1º/jan até ontem, com zero quando não há pedido. Com tipo, forma a chave"),
  ALTER COLUMN tipo SET OPTIONS(description="Tipo de input da silver: Inbound ou Mercado (as séries da previsão de demanda)"),
  ALTER COLUMN dia_util SET OPTIONS(description="TRUE = segunda a sexta fora do calendário sem expediente (feriados nacionais, RJ, SP, Carnaval, Cinzas, Sexta-feira Santa, Corpus Christi e vésperas de Natal e Ano-Novo)"),
  ALTER COLUMN exclusivos SET OPTIONS(description="Pedidos com talento exclusivo na data do pedido"),
  ALTER COLUMN nao_exclusivos SET OPTIONS(description="Pedidos com talento não exclusivo na data do pedido (inclui Squad de Talentos)"),
  ALTER COLUMN sem_talento SET OPTIONS(description="Pedidos sem exclusividade definida na silver (sem talento)"),
  ALTER COLUMN total SET OPTIONS(description="exclusivos + nao_exclusivos + sem_talento; igual às entradas do dia e tipo na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução");

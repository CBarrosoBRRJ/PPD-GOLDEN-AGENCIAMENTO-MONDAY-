-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_2026_previsao_lotes.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_lotes` SET OPTIONS(description="Pedidos do board 2026 por dia de entrada e recorte da previsão (inbound, mercado, mercado_exclusivos, mercado_nao_exclusivos), separados em pedidos em lote (3 ou mais do recorte com a mesma marca no mesmo dia) e avulsos, de 1º/jan até ontem; só dias com pedido. Pedidos de cada dia e recorte iguais à gld_agenciamento_2026_previsao_exclusividade_diaria. Diagnóstico do mês em andamento da previsão. Uma linha por dia × recorte. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_previsao_lotes.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_previsao_lotes`
  ALTER COLUMN data SET OPTIONS(description="Data de entrada dos pedidos (regras de data da gld_agenciamento_entrada_diaria), de 1º/jan até ontem; só dias com pedido no recorte. Com recorte, forma a chave"),
  ALTER COLUMN recorte SET OPTIONS(description="inbound, mercado, mercado_exclusivos ou mercado_nao_exclusivos (os recortes da previsão; os dois últimos são partes do mercado com exclusividade definida)"),
  ALTER COLUMN pedidos SET OPTIONS(description="Pedidos do recorte no dia; igual ao total do dia na gld_agenciamento_2026_previsao_exclusividade_diaria"),
  ALTER COLUMN em_lote SET OPTIONS(description="Pedidos que fazem parte de um lote: 3 ou mais pedidos do recorte com a mesma marca (ou prefixo [Marca] do nome) no mesmo dia"),
  ALTER COLUMN avulsos SET OPTIONS(description="pedidos − em_lote (inclui os sem marca)"),
  ALTER COLUMN lotes SET OPTIONS(description="Quantos lotes (marcas com 3 ou mais pedidos no recorte e no dia)"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução");

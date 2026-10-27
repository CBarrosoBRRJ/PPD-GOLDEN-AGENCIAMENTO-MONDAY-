-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_2026_talentos_ano.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano` SET OPTIONS(description="Divisão anual dos pedidos do board 2026 entre Exclusivos, Não exclusivos (inclui Squad de Talentos) e Sem talento, de 1º/jan até ontem, com a exclusividade na data do pedido (silver) e as regras de data da gld_agenciamento_entrada_diaria; o total é igual às entradas do ano da diária. Uma linha por categoria. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_talentos_ano.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ano`
  ALTER COLUMN ano SET OPTIONS(description="Ano dos pedidos (o de ontem). Conta de 1º/jan até ontem, pela data de entrada da gld_agenciamento_entrada_diaria (criado_em; cadastro retroativo pela data_de_entrada; sem criado_em, data_de_saida − 5 dias úteis)"),
  ALTER COLUMN categoria SET OPTIONS(description="Exclusivos, Não exclusivos (inclui Squad de Talentos) ou Sem talento (exclusividade nula na silver). Com ano, forma a chave"),
  ALTER COLUMN n SET OPTIONS(description="Pedidos (cards ativos do board 2026) da categoria no ano"),
  ALTER COLUMN total SET OPTIONS(description="Pedidos do ano nas três categorias; igual às entradas do ano na gld_agenciamento_entrada_diaria (quantidade + quantidade_estimada)"),
  ALTER COLUMN pct SET OPTIONS(description="Participação da categoria em %, 1 casa decimal; as três somam 100,0 (maior resto)"),
  ALTER COLUMN dos_quais_squad SET OPTIONS(description="Dos pedidos da categoria, quantos têm talento Squad de Talentos (um grupo, não uma pessoa)"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução");

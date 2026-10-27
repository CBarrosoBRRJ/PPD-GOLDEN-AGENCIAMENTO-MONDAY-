-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_2026_talentos_ranking.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ranking` SET OPTIONS(description="Ranking de talentos do board 2026 no ano (1º/jan até ontem), por recorte (todos, exclusivo, nao-exclusivo): os 10 com mais pedidos e os que passaram pelos 10 do acumulado no fim de algum mês (corrida do ano), com os pedidos de cada um mês a mês. Mesma população da gld_agenciamento_2026_talentos_ano; sem Squad de Talentos e sem pedidos sem talento. Uma linha por recorte × talento × mês com pedido. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_talentos_ranking.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_talentos_ranking`
  ALTER COLUMN grupo SET OPTIONS(description="Recorte: todos (exclusivos + não exclusivos pelo mesmo nome), exclusivo ou nao-exclusivo. Com talento e mes, forma a chave"),
  ALTER COLUMN talento SET OPTIONS(description="Nome do talento na grafia mais frequente do recorte (agrupado sem diferença de maiúsculas e espaços). Sem Squad de Talentos e sem pedidos sem talento"),
  ALTER COLUMN n SET OPTIONS(description="Pedidos do talento no ano (1º/jan até ontem), no recorte; repete em todas as linhas do talento"),
  ALTER COLUMN ultimo_pedido SET OPTIONS(description="Data de entrada do último pedido do talento no ano, no recorte"),
  ALTER COLUMN empate_fora SET OPTIONS(description="Talentos do recorte fora da lista com o mesmo número de pedidos do 10º lugar (a tela mostra \"empate com mais N\"); repete no recorte"),
  ALTER COLUMN talentos_grupo SET OPTIONS(description="Talentos nomeados com pedido no ano, no recorte; repete no recorte"),
  ALTER COLUMN mes SET OPTIONS(description="1º dia do mês dos pedidos (mês da data de entrada); só meses com pedido do talento"),
  ALTER COLUMN n_mes SET OPTIONS(description="Pedidos do talento no mês, no recorte"),
  ALTER COLUMN pos SET OPTIONS(description="Lugar do talento no ano, no recorte (1 = mais pedidos; empate pela ordem alfabética). pos > 10 = esteve entre os 10 do acumulado no fim de algum mês, mas não fechou o ano entre os 10"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução");

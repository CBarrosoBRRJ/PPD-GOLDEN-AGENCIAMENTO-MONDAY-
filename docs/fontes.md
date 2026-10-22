# Fontes: colunas das silvers

Referência para escolher as colunas de cada tabela gold. Esquemas lidos do BigQuery em 21/10/2026; as regras de cada
coluna estão em `../PPD-SILVER-MONDAY/docs/PRD.md` (seção 6 para os itens; seção 5 e `processos/agenciamento_log.md`
para o log).

## `silver_monday.slv_agenciamento_2026_itens` — uma linha por projeto (5.467; cluster `projeto_id`)

| Bloco | Coluna | Tipo | Observação |
|---|---|---|---|
| Identificação | `projeto_id` | STRING | chave única do projeto do início ao fim |
| | `item_id_atual` | STRING | ID no board atual |
| | `item_id_legado` | STRING | ID no board antigo (migração de 03/09/2026) |
| | `board_id` | STRING | |
| | `nome_projeto` | STRING | padrão `[Marca] Talento \| Projeto` |
| | `link_projeto` | STRING | link do projeto no monday |
| | `state` | STRING | `active` / `deleted` |
| | `grupo_projeto` | STRING | chave de relação com o log |
| | `pendente_revisao` | BOOL | par legado → atual não confirmado |
| Grupo e status | `grupo_id` | STRING | |
| | `grupo_nome` | STRING | Entrada, Em elaboração, Aguardando Feedback… |
| | `status` | STRING | forma oficial; vazio = "Entrada" |
| Pessoas | `criador_id`, `criador_nome` | STRING | criador real (nos migrados, o do log legado) |
| | `criador_origem` | STRING | `legado` / `atual` |
| | `orcamento` | STRING | e-mails; nunca vazio (regra de preenchimento) |
| | `audiencia`, `conteudo`, `gp`, `producao`, `talent_manager` | STRING | e-mails separados por `, ` |
| | `contato` | STRING | texto limpo |
| Datas | `criado_em` | DATETIME | criação real (Brasília) |
| | `atualizado_em` | DATETIME | último evento do log |
| | `data_de_entrada` | DATE | vazia = data de criação |
| | `data_de_saida` | DATE | significado ainda não confirmado pela equipe |
| | `deadline` | DATE | |
| | `data_da_venda` | DATE | vendido sem data = dia do "Vendido = Sim" no log |
| | `data_de_veiculacao` | STRING | é uma **lista de prazos**, não uma data |
| Talento | `talento` | STRING | um nome, ou "Squad de Talentos" |
| | `exclusivo` | BOOL | exclusivo **na data do projeto** |
| | `talentos_exclusivos`, `interveniencia` | STRING | colunas originais tratadas |
| Marca | `marca` | STRING | uma marca (Catálogo de Marcas) |
| | `marca_nivel` | STRING | Marca, Grupo, Produto, Não-marca |
| | `marca_grupo` | STRING | marca-mãe |
| | `marcas_do_projeto` | STRING | todas, separadas por `, ` |
| | `produto_globo` | BOOL | produto da casa |
| Classificação | `categoria`, `segmento` | STRING | obrigatórias no recorte |
| | `tipo_de_input`, `tipo_de_output`, `tipo_de_projeto` | STRING | obrigatórias no recorte |
| | `impacto`, `captacao`, `edicao` | STRING | |
| Comercial | `vendido` | BOOL | |
| | `valor_da_proposta` | NUMERIC | zero = NULL |
| | `qtd_de_cotas` | INT64 | |
| Marcadores do nome | `upfront`, `curadoria`, `defesa`, `levop`, `midia_kit`, `analise` | BOOL | palavra no nome do projeto |
| Divergências e recorte | `divergencia_interveniencia`, `divergencia_curadoria` | BOOL | avisos |
| | `no_recorte_de_cobranca` | BOOL | projetos que a MIA cobra |
| Fórmulas do monday | `sla_entrada_da_demanda`, `total_score` | INT64 | como vêm, sem recalcular |
| | `prioridade` | STRING | como vem |
| Links | `link_da_pasta_orcamento`, `link_da_pasta_planejamento`, `link_da_proposta`, `link_do_email`, `link_sf`, `monday_doc_v2`, `formulario` | STRING | |
| Técnicas | `lia_chave_sync_nao_editar`, `subitems` | STRING | |
| | `fonte_ingerido_em` | TIMESTAMP | rastreio da bronze |
| | `fonte_run_id`, `fonte_operacao` | STRING | rastreio da bronze |
| | `_processado_em` | TIMESTAMP | execução da silver |

## `silver_monday.slv_agenciamento_2026_log` — um evento por linha (178.151; partição `data_alteracao`, cluster `projeto_id`)

| Bloco | Coluna | Tipo | Observação |
|---|---|---|---|
| Projeto | `projeto_id` | STRING | liga com os itens |
| | `nome_projeto`, `marca` | STRING | |
| | `item_id_atual`, `item_id_legado`, `item_id_origem` | STRING | |
| | `conta_origem`, `board_id` | STRING | conta e board de onde veio o evento |
| | `grupo_projeto` | STRING | |
| | `pendente_revisao`, `teve_relacao` | BOOL | |
| Quando | `alterado_em` | DATETIME | Brasília |
| | `alterado_em_utc` | TIMESTAMP | |
| | `data_alteracao` | DATE | **partição**: filtre sempre por ela para reduzir custo |
| | `ano_mes` | STRING | |
| O que mudou | `tipo_evento`, `categoria_evento` | STRING | |
| | `campo_alterado`, `campo_alterado_id`, `campo_alterado_tipo` | STRING | coluna do monday alterada |
| | `valor_antes`, `valor_depois`, `valor_leitura` | STRING | |
| | `grupo_id`, `grupo_no_momento` | STRING | grupo do projeto no momento do evento |
| Quem mudou | `alterado_por_id`, `alterado_por_nome`, `alterado_por_email` | STRING | |
| | `alterado_por_automacao` | BOOL | |
| Rastreio | `log_id`, `log_id_origem`, `uuid_acao` | STRING | |
| | `evento_derivado_lote` | BOOL | |
| | `fonte_arquivo`, `fonte_run_id` | STRING | |
| | `fonte_carregado_em` | DATETIME | |
| | `dados_json` | STRING | evento bruto |
| | `_processado_em` | TIMESTAMP | |

-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_fluxo_mensal.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal` SET OPTIONS(description="Extrato por safra do Agenciamento (boards 2024, 2025 e 2026): para os cards que entraram em cada mês (mes_entrada, de 2024-10 em diante), o que aconteceu até hoje e em que mês — entregue (1ª entrega ao cliente), nao_seguiu (Declinado, Standby ou Encerrado sem entrega; mês pelo log do board 2026, NULL em 2024/2025) ou em_andamento — por grupo de input, tipo de input e família. Cada card conta uma vez. Mesmas regras de card da gld_agenciamento_entrada_diaria. Foto do dia: recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_fluxo_mensal.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_fluxo_mensal`
  ALTER COLUMN mes_entrada SET OPTIONS(description="1º dia do mês de entrada do card (safra), com as regras de data da gld_agenciamento_entrada_diaria (criado_em; cadastro retroativo pela data_de_entrada; sem criado_em, data_de_saida − 5 dias úteis); de 2024-10 até o mês de ontem. Com evento, mes_evento, grupo_input, tipo_de_input e familia, forma a chave"),
  ALTER COLUMN evento SET OPTIONS(description="O que aconteceu com o card até hoje: entregue (1ª entrega ao cliente, a mesma saída da quantidade_saida da diária), nao_seguiu (sem entrega e status atual Declinado, Standby ou Encerrado) ou em_andamento (os demais). Um evento por card"),
  ALTER COLUMN mes_evento SET OPTIONS(description="1º dia do mês do evento: entregue = mês da 1ª entrega; nao_seguiu = mês em que o card chegou ao status atual, pelo log (board 2026); NULL nos boards 2024/2025 (sem log) e quando o log não tem a mudança; em_andamento = NULL. Nunca antes de mes_entrada"),
  ALTER COLUMN grupo_input SET OPTIONS(description="Mercado, Inbound, Proativo, Internos (ViU, Interna, Globo, ViU First, OTR) ou Sem tipo (vazio); Outros = tipo novo ainda sem grupo. Como na diária"),
  ALTER COLUMN tipo_de_input SET OPTIONS(description="Valor original da silver; vazio = Sem tipo. Como na diária"),
  ALTER COLUMN familia SET OPTIONS(description="Upfront, Levop, Mídia Kit, Análise, Defesa, Curadoria, Card de Oportunidade (Levop), Curadoria Orçada, Defesas | Estudo Comercial ou Nenhuma; com mais de uma, vale a primeira desta ordem. Como na diária"),
  ALTER COLUMN quantidade SET OPTIONS(description="Cards da combinação (cada card conta uma vez, num evento só). Foto do dia: os em andamento migram para entregue ou não seguiu"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução");

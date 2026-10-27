-- GERADO por tools/gerar_deploy.py a partir de sql/esquemas/gld_agenciamento_2026_sla_movimentos.csv.
-- Não editar à mão: altere o esquema e gere de novo.
-- Executar no BigQuery com a conta corporativa, no projeto gglobo-viu-dados-hdg-prd (região US).
-- Só atualiza as descrições da tabela e das colunas: não mexe em dados, esquema nem permissões. Seguro
-- repetir. Toda coluna do esquema precisa existir na tabela (coluna nova é por ALTER TABLE ... ADD COLUMN).
-- Duas instruções (tabela; todas as colunas numa só): cota de 5 atualizações de metadado por tabela / 10 s.

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos` SET OPTIONS(description="SLA do board Backlog 2026 | Agenciamento: uma linha por passagem de um projeto por um status (projeto_id + passo), com fase (equipe, cliente, standby, fechamento), tempo corrido e útil, tempo em aberto, alerta e marcações do fluxo. Recriada a cada execução. Regras: docs/tabelas/gld_agenciamento_2026_sla_movimentos.md (PPD-GOLDEN-AGENCIAMENTO-MONDAY)");

ALTER TABLE `gglobo-viu-dados-hdg-prd.gold_monday.gld_agenciamento_2026_sla_movimentos`
  ALTER COLUMN projeto_id SET OPTIONS(description="Chave do projeto do início ao fim (igual à silver; atravessa a migração de 03/09/2026). Com passo, forma a chave da tabela"),
  ALTER COLUMN item_id_atual SET OPTIONS(description="ID do item no board atual do monday"),
  ALTER COLUMN item_id_legado SET OPTIONS(description="ID do item no board antigo (conta viu2); vazio nos projetos criados depois da migração"),
  ALTER COLUMN board_id SET OPTIONS(description="ID do board no monday"),
  ALTER COLUMN nome_projeto SET OPTIONS(description="Nome do projeto, como na silver"),
  ALTER COLUMN status_atual SET OPTIONS(description="Status do projeto hoje (foto do dia); serve para filtrar, ex.: só encerrados"),
  ALTER COLUMN talento SET OPTIONS(description="Talento do projeto (silver): um nome, Squad de Talentos (mais de um) ou vazio"),
  ALTER COLUMN exclusivo SET OPTIONS(description="O talento era exclusivo na data do projeto (silver); vazio sem talento"),
  ALTER COLUMN tipo_de_input SET OPTIONS(description="Tipo de input (forma oficial da silver)"),
  ALTER COLUMN tipo_de_output SET OPTIONS(description="Tipo de output (forma oficial da silver)"),
  ALTER COLUMN marca SET OPTIONS(description="Marca do projeto (Catálogo de Marcas, pela silver)"),
  ALTER COLUMN orcamento SET OPTIONS(description="Nome da pessoa da equipe de orçamento (R5); mais de uma = nomes separados por vírgula, na ordem do monday. É o responsável de hoje, não o da época de cada passo"),
  ALTER COLUMN passo SET OPTIONS(description="Ordem da passagem do projeto pelos status (1 = Entrada)"),
  ALTER COLUMN status SET OPTIONS(description="Status desta passagem (como no log; nomes antigos mantidos)"),
  ALTER COLUMN fase SET OPTIONS(description="Relógio do SLA (R15): equipe (Entrada, elaboração, revisão e status novos), cliente (Aguardando Feedback), standby (Standby, relógio próprio) ou fechamento (Encerrado, Negócio Fechado, Declinado, Sem retorno)"),
  ALTER COLUMN entrada SET OPTIONS(description="Quando o projeto chegou neste status (horário de Brasília)"),
  ALTER COLUMN saida SET OPTIONS(description="Quando o projeto mudou para o status seguinte (horário de Brasília); vazio = status atual"),
  ALTER COLUMN saida_horario SET OPTIONS(description="Horário da mudança que encerrou o passo (R21): expediente, antes do expediente, depois do expediente ou fim de semana ou feriado"),
  ALTER COLUMN saida_por SET OPTIONS(description="Quem fez a mudança que encerrou o passo (nome no monday; a automação aparece como Automação do monday)"),
  ALTER COLUMN saida_por_automacao SET OPTIONS(description="A mudança que encerrou o passo foi feita por uma automação (ex.: Encerrado automático 30 dias depois de Aguardando Feedback)"),
  ALTER COLUMN sla_corrido_horas SET OPTIONS(description="Tempo no status em horas corridas (saída − entrada; R13); vazio enquanto o status não termina"),
  ALTER COLUMN sla_util_horas SET OPTIONS(description="Tempo no status em horas úteis (R13): só seg–sex, 10h–19h, fora de feriados e dias sem expediente (R14); vazio enquanto o status não termina"),
  ALTER COLUMN fora_expediente SET OPTIONS(description="A mudança que encerrou o passo foi feita por uma pessoa fora do horário (R20); a automação não conta"),
  ALTER COLUMN hora_extra_horas SET OPTIONS(description="Hora extra estimada (R20): depois do expediente = das 19h (ou da entrada) até a mudança; antes do expediente ou fim de semana/feriado = da entrada até a mudança, só no mesmo dia; vazio quando não se aplica ou não dá para estimar"),
  ALTER COLUMN sla_corrido SET OPTIONS(description="Leitura do tempo corrido: Xd HHhMM (1 dia = 24 h)"),
  ALTER COLUMN sla_util SET OPTIONS(description="Leitura do tempo útil: Xd HHhMM (1 dia útil = 9 h)"),
  ALTER COLUMN em_aberto SET OPTIONS(description="Status atual ainda em andamento (fase equipe, cliente ou standby; R17)"),
  ALTER COLUMN aberto_ha_corrido_horas SET OPTIONS(description="Há quanto tempo o status atual está aberto, em horas corridas, até a execução (_processado_em); muda a cada execução"),
  ALTER COLUMN aberto_ha_util_horas SET OPTIONS(description="Há quanto tempo o status atual está aberto, em horas úteis, até a execução; muda a cada execução"),
  ALTER COLUMN alerta SET OPTIONS(description="Cliente sem retorno: em Aguardando Feedback, em aberto, há mais de 10 dias úteis (R18; limite provisório)"),
  ALTER COLUMN retrabalho SET OPTIONS(description="Voltou de Aguardando Feedback para um status da equipe (R19)"),
  ALTER COLUMN reaberto SET OPTIONS(description="Saiu de um fechamento (Encerrado, Declinado) e voltou a andar (R19)"),
  ALTER COLUMN entrega_sem_aguardando SET OPTIONS(description="Fechou vindo da equipe sem registrar a nova entrega em Aguardando Feedback, depois de já ter ido ao cliente (R19); Declinado não conta"),
  ALTER COLUMN encerrado_sem_entrega SET OPTIONS(description="Fechou vindo da equipe sem nunca ter ido ao cliente (R19); Declinado não conta"),
  ALTER COLUMN link_projeto SET OPTIONS(description="Link do projeto no monday"),
  ALTER COLUMN _processado_em SET OPTIONS(description="Momento da execução que gerou a tabela"),
  ALTER COLUMN sla_sem_almoco_horas SET OPTIONS(description="Tempo útil do status concluído sem o almoço, em horas, sem arredondar (R24): mesmos dias úteis do sla_util_horas, só das 10h às 13h e das 14h às 19h (dia útil = 8 h); NULL enquanto o status não termina. Nunca maior que sla_util_horas (fora o arredondamento dele, de 2 casas)");

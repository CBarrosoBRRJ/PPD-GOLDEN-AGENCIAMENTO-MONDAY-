# `gold_monday.gld_agenciamento_2026_sla_movimentos`

| | |
|---|---|
| **Situação** | 🚀 em produção desde 21/10/2026 (1ª carga pelo job às 18:16 de Brasília; atualização seg–sex 09:00) |
| **Pergunta** | quanto tempo cada projeto ficou em cada status, de quem era o relógio (equipe, cliente, standby) e onde o fluxo desviou |
| **Por que existe** | o monday só mostra o status atual de cada card, e o log tem 178 mil eventos que ninguém lê à mão; não havia medida de quanto tempo cada projeto ficou com a equipe, com a marca ou parado, nem de onde o fluxo desvia (retrabalho, reabertura, fechamento sem entrega) |
| **O que esperamos fazer** | Power BI de SLA por fase, status e responsável; cobrança de marca sem retorno (`alerta`); medir retrabalho, reabertura e trabalho fora do expediente; base para a meta de SLA da equipe (L1 em `docs/melhorias_processo.md`) e para o site de relatórios |
| **Saída esperada** | uma linha por passagem de projeto por status (≈ 15 mil linhas, ≈ 3.100 projetos), com horas corridas e úteis, fase, em aberto, alerta e marcações do fluxo; recalculada por inteiro a cada execução; 19 verificações ok em toda carga |
| **Uma linha por** | passagem de um projeto por um status — chave `projeto_id` + `passo` |
| **Quem usa** | Power BI (e, no futuro, o site de relatórios) |
| **Fontes** | `silver_monday.slv_agenciamento_2026_itens` (recorte e atributos) e `silver_monday.slv_agenciamento_2026_log` (mudanças de Status) |
| **Materialização** | **tabela**, cluster `projeto_id, status_atual`, sem partição (≈ 15 mil linhas). Criada uma vez por `deploy/criar_…sql`; atualizada **seg–sex 09:00** pelo job `gold-agenciamento` (valida antes e troca o conteúdo numa transação) |
| **Arquivos** | SELECT: [`sql/gld_agenciamento_2026_sla_movimentos.sql`](../../sql/gld_agenciamento_2026_sla_movimentos.sql) · esquema: [`sql/esquemas/…csv`](../../sql/esquemas/gld_agenciamento_2026_sla_movimentos.csv) · criação (gerada): [`deploy/criar_…sql`](../../deploy/criar_gld_agenciamento_2026_sla_movimentos.sql) · validação: [`sql/validacoes/…sql`](../../sql/validacoes/gld_agenciamento_2026_sla_movimentos.sql) |
| **Custo** | ≈ 27 MB lidos por execução (dry-run de 21/10/2026; reserva Enterprise do projeto) |

## 1. Como ler a tabela

Cada projeto aparece em várias linhas, uma por status pelo qual passou, em ordem (`passo` 1 = Entrada). Os atributos
do projeto (nome, talento, marca, orçamento…) se repetem em todas as linhas. `entrada` é quando o projeto chegou no
status; `saida`, quando mudou para o próximo (vazia no status atual). O tempo no status vem em horas **corridas** e
**úteis**. A `fase` diz de quem é o relógio:

| Fase | Status | Relógio de |
|---|---|---|
| `equipe` | Entrada, todas as elaborações e revisões, e qualquer status novo | equipe (da Entrada até entrar em Aguardando Feedback; volta a contar se o projeto voltar) |
| `cliente` | Aguardando Feedback | marca (até o fechamento ou a volta para a equipe) |
| `standby` | Standby | ninguém — relógio próprio |
| `fechamento` | Encerrado, Negócio Fechado, Declinado…, Sem retorno… | ninguém (fim do ciclo; se reabrir, o tempo parado aparece, mas não conta) |

No Power BI: **SLA da equipe** = soma de `sla_util_horas` com `fase = equipe`; **espera da marca** = soma com
`fase = cliente`; status em andamento = `em_aberto`; cobrança da marca = `alerta`.

## 2. Pipeline (ordem do SQL)

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros` | momento da execução, limite do alerta (10 dias úteis), limite do clique (2 min) | R17, R18, R22 |
| 2 | `projetos` | recorte dos projetos e atributos (itens da silver) | R1–R4, R11, R12 |
| 3 | `pessoas`, `orcamento` | e-mail do Orçamento → nome | R5 |
| 4 | `eventos` | mudanças de Status do log, em ordem | R6 |
| 5 | `inicial`, `passos` | 1º status (Entrada) desde a criação + cada mudança; status limpo não conta | R7, R8 |
| 6 | `sem_repeticao` | mesmo status em sequência = uma passagem | R9 |
| 7 | `sem_clique`, `sem_clique_repeticao` | ida e volta < 2 min = clique corrigido | R22 |
| 8 | `historico` | passo, status (forma oficial), entrada, saída, quem fez a mudança | R10, R21 |
| 9 | `fases` | equipe, cliente, standby, fechamento | R15 |
| 10 | `anos`, `pascoa`, `feriados` | calendário sem expediente, calculado por ano | R14 |
| 11 | `tempo` | tempo corrido e útil; horário da mudança | R13, R17, R21 |
| 12 | `extra` | trabalho fora do expediente e hora extra estimada | R20 |
| 13 | SELECT final | colunas na ordem do esquema; alerta e marcações do fluxo | R18, R19 |

## 3. Colunas (36)

Fonte única: [`sql/esquemas/gld_agenciamento_2026_sla_movimentos.csv`](../../sql/esquemas/gld_agenciamento_2026_sla_movimentos.csv)
(as descrições vão para o BigQuery na criação).

| # | Coluna | Tipo | Bloco | Descrição |
|---|---|---|---|---|
| 1 | `projeto_id` | STRING | projeto | chave do projeto do início ao fim; com `passo`, chave da tabela |
| 2 | `item_id_atual` | STRING | projeto | ID no board atual |
| 3 | `item_id_legado` | STRING | projeto | ID no board antigo; vazio nos criados depois de 03/09/2026 |
| 4 | `board_id` | STRING | projeto | ID do board |
| 5 | `nome_projeto` | STRING | projeto | nome, como na silver |
| 6 | `status_atual` | STRING | projeto | status de hoje (foto do dia) |
| 7 | `talento` | STRING | projeto | um nome, "Squad de Talentos" ou vazio |
| 8 | `exclusivo` | BOOL | projeto | exclusivo na data do projeto |
| 9 | `tipo_de_input` | STRING | projeto | forma oficial da silver |
| 10 | `tipo_de_output` | STRING | projeto | forma oficial da silver |
| 11 | `marca` | STRING | projeto | Catálogo de Marcas |
| 12 | `orcamento` | STRING | projeto | nome(s) da equipe de orçamento (R5) — o de hoje |
| 13 | `passo` | INT64 | passo | ordem da passagem (1 = Entrada) |
| 14 | `status` | STRING | passo | status desta passagem |
| 15 | `fase` | STRING | passo | equipe, cliente, standby, fechamento (R15) |
| 16 | `entrada` | DATETIME | passo | chegou no status (Brasília) |
| 17 | `saida` | DATETIME | passo | mudou para o próximo; vazio = status atual |
| 18 | `saida_horario` | STRING | mudança | expediente, antes/depois do expediente, fim de semana ou feriado (R21) |
| 19 | `saida_por` | STRING | mudança | quem mudou o status |
| 20 | `saida_por_automacao` | BOOL | mudança | a mudança foi da automação |
| 21 | `sla_corrido_horas` | FLOAT64 | tempo | horas corridas no status (R13) |
| 22 | `sla_util_horas` | FLOAT64 | tempo | horas úteis no status (R13, R14) |
| 23 | `fora_expediente` | BOOL | tempo | pessoa mudou o status fora do horário (R20) |
| 24 | `hora_extra_horas` | FLOAT64 | tempo | hora extra estimada (R20) |
| 25 | `sla_corrido` | STRING | tempo | leitura `Xd HHhMM` (1 d = 24 h) |
| 26 | `sla_util` | STRING | tempo | leitura `Xd HHhMM` (1 d útil = 9 h) |
| 27 | `em_aberto` | BOOL | em aberto | status atual em andamento (R17) |
| 28 | `aberto_ha_corrido_horas` | FLOAT64 | em aberto | horas corridas até a execução |
| 29 | `aberto_ha_util_horas` | FLOAT64 | em aberto | horas úteis até a execução |
| 30 | `alerta` | BOOL | em aberto | cliente sem retorno há mais de 10 dias úteis (R18) |
| 31 | `retrabalho` | BOOL | fluxo | voltou de Aguardando Feedback para a equipe (R19) |
| 32 | `reaberto` | BOOL | fluxo | saiu de um fechamento e voltou a andar (R19) |
| 33 | `entrega_sem_aguardando` | BOOL | fluxo | fechou sem registrar a nova entrega, depois de já ter ido ao cliente (R19) |
| 34 | `encerrado_sem_entrega` | BOOL | fluxo | fechou sem nunca ter ido ao cliente (R19) |
| 35 | `link_projeto` | STRING | rastreio | link no monday |
| 36 | `_processado_em` | TIMESTAMP | rastreio | momento da execução |

Vazios ficam NULL (no Power BI, "(Em branco)"); a gold não preenche atributos — a silver já aplicou as regras.

## 4. Regras

Os IDs são os da construção (21/10/2026) e não são renumerados; R16 é de uma variação futura (seção 8).

### 4.1 Recorte de projetos

| ID | Regra | Efeito (21/10/2026) |
|---|---|---|
| R1 | Status **atual** = Aguardando Feedback ou um fechamento (começa por Encerrado, Negócio Fechado, Declinado ou Sem retorno — status novo de fechamento entra sozinho). Pelo **Status**, não pelo grupo | 5.020 (de 5.467 itens) |
| R2 | Sem projetos excluídos (`state = 'deleted'`) | −13 → 5.007 |
| R3 | Sem marcadores do nome: `upfront`, `curadoria`, `defesa`, `levop`, `midia_kit`, `analise` (NULL conta como FALSE) | −359 → 4.648 |
| R4 | Sem os outputs `Levop \| Card de Oportunidade \| Informação por e-mail`, `Curadoria Orçada`, `Defesas \| Estudo Comercial \| Curadorias` (output vazio fica) | −161 → 4.487 |
| R11 | Só projetos com alguma mudança de Status no log (sem histórico, o tempo seria inventado) | −122 → 4.365 |
| R12 | Só projetos cujo histórico **começa em Entrada**: 1ª mudança é Entrada → outro, ou vazio → Entrada | −1.270 → **3.095** |
| R23 | Sem `criado_em` não entra (o 1º passo ficaria sem entrada e sem tempo). Decisão do Caio, 22/10/2026, a partir da revisão do Codex | 0 projetos afetados em 22/10/2026 (os 5 ativos sem `criado_em` já ficavam fora do recorte) |

Ressalva do R12: jan–mai/2026 ficam com 46–67% dos projetos por mês (jun–out 78–92%), porque o board antigo
registrava muitos projetos nascendo sem status e indo direto para outro (caso "vazio → outro", 692) ou já num status do
meio (578). Decisão do Caio: manter só o fluxo completo e ordenado.

### 4.2 Atributos

| ID | Regra |
|---|---|
| R5 | Orçamento: cada e-mail da célula vira o nome mais recente da pessoa no log da silver; mais de um = nomes separados por `, ` na ordem da célula; sem nome conhecido = o próprio e-mail. Conferido: os 15 e-mails batem com o nome oficial da silver |

### 4.3 Histórico de status

| ID | Regra |
|---|---|
| R6 | Só `campo_alterado = 'Status'` do log, em ordem de `alterado_em` (desempate `log_id`) |
| R7 | 1º passo = o `valor_antes` da 1ª mudança (ou Entrada), desde a criação do projeto (ou o 1º evento, se vier antes — 2 projetos, 4 s) |
| R8 | Mudança que limpa o Status (`valor_depois` vazio) não conta |
| R9 | O mesmo status em sequência vale uma passagem (vale a 1ª entrada) |
| R10 | "Em Elaboração - Orçamentos" → "Em elaboração - Orçamentos" (forma oficial da silver), aplicada **antes** de R9 e R22 (desde 22/10/2026), para a grafia antiga e a oficial em sequência contarem como uma passagem; os demais nomes ficam como no log, inclusive os antigos ("Em Elaboração" até 14/05, "Em elaboração GP", "Cotação Externa", "Em revisão (Planejamento)"…) |
| R22 | **Clique corrigido**: A → B → A com B < 2 min (parâmetro `limite_clique_minutos`) — B sai e os dois A viram uma passagem. Corte pelos dados: < 2 min 154 casos (95 com Aguardando Feedback); 2–10 min 44 (2 com o cliente). Efeito: 15.010 → 14.776 linhas; retrabalho 300 → 245 |

### 4.4 Fases e tempo

| ID | Regra |
|---|---|
| R15 | Fase de cada status: `cliente` = Aguardando Feedback; `standby` = Standby; `fechamento` = começa por Encerrado, Negócio Fechado, Declinado ou Sem retorno; `equipe` = todo o resto (status novo cai aqui) |
| R13 | Tempo no status: **corrido** = saída − entrada; **útil** = só o que cai em dia útil das 10h às 19h (dia útil = 9 h). Vazio enquanto o status não termina (o número de uma etapa nunca muda depois de gravado) |
| R14 | Dias sem expediente, **calculados para cada ano** (2020 até o ano seguinte ao atual): fixos — 01/01, 20/01 (São Sebastião, RJ), 25/01 (cidade de SP), 21/04, 23/04 (São Jorge, RJ), 01/05, 09/07 (estado de SP), 07/09, 12/10, 02/11, 15/11, 20/11, 24/12, 25/12, 31/12; móveis pela Páscoa (Meeus) — segunda e terça de Carnaval, Quarta-feira de Cinzas, Sexta-feira Santa, Corpus Christi; lista de exceções pontuais (vazia). Conferido: Páscoa de 2025, 2026, 2027 e 2030 |
| R17 | **Em aberto**: no status atual de fase equipe, cliente ou standby, `em_aberto` = TRUE e `aberto_ha_*` = tempo da entrada até a execução (muda a cada execução) |
| R18 | **Alerta**: em aberto em Aguardando Feedback há mais de **10 dias úteis** (parâmetro `alerta_dias_uteis_cliente`; provisório até a meta da equipe — L1) |

### 4.5 Mudança, fora do expediente e marcações do fluxo

| ID | Regra |
|---|---|
| R21 | A mudança que encerrou o passo: `saida_horario` (expediente; antes do expediente = dia útil antes das 10h; depois = dia útil a partir das 19h; fim de semana ou feriado), `saida_por`, `saida_por_automacao` |
| R20 | `fora_expediente` = uma **pessoa** (não a automação) fez a mudança fora do horário. `hora_extra_horas` (estimativa): depois do expediente = das 19h (ou da entrada, se depois) até a mudança; antes do expediente ou fim de semana/feriado = da entrada até a mudança, só se no mesmo dia (senão vazio) |
| R19 | `retrabalho` = equipe vindo de cliente; `reaberto` = qualquer passo vindo de um fechamento; `entrega_sem_aguardando` / `encerrado_sem_entrega` = fechamento que **não** é Declinado, vindo direto da equipe ou do Standby, com / sem passagem anterior pelo cliente (olha o passo imediatamente anterior) |

## 5. Números do ensaio (21/10/2026)

| Indicador | Valor |
|---|---|
| Projetos / linhas | 3.095 / 14.776 |
| Mediana do tempo da equipe por projeto | ≈ 18 h úteis (≈ 2 dias úteis) |
| Em aberto (todos com o cliente) / em alerta | 378 / 230 |
| Retrabalho / reaberto | 245 passos / 75 passos |
| Entrega sem Aguardando Feedback / encerrado sem entrega | 21 / 33 |
| Passaram por Standby | 28 projetos |
| Mudanças por pessoas fora do expediente | 1.622 (depois das 19h 1.480; antes das 10h 100; fim de semana/feriado 42); ≈ 1.277 h extras estimadas |
| Mudanças pela automação | ≈ 2.120 (quase todas o Encerrado da meia-noite) |

## 6. Validação

Arquivo: [`sql/validacoes/gld_agenciamento_2026_sla_movimentos.sql`](../../sql/validacoes/gld_agenciamento_2026_sla_movimentos.sql)
(19 verificações; rodar depois de cada criação). Ensaio de 21/10/2026, sobre o SELECT: **16 de 16 OK**. Em
22/10/2026 entraram 3 verificações (entrada preenchida — R23; passo concluído com tempo corrido e útil; nenhum status
repetido em sequência — R9 depois de R10), todas com 0 na tabela de produção.

| Verificação | Resultado |
|---|---|
| chave projeto + passo única; passos 1..N sem buraco | ✅ |
| todo projeto começa em Entrada; último passo = status atual da silver | ✅ |
| só o último passo sem saída; saída nunca antes da entrada | ✅ |
| útil ≤ corrido, sem negativos; hora extra ≤ corrido | ✅ |
| em aberto só no último passo e fora de fechamento; alerta só com cliente em aberto | ✅ |
| fase conhecida; orçamento e link preenchidos; `_processado_em` único | ✅ |
| entrada preenchida; passo concluído com tempo; sem status repetido em sequência (22/10/2026) | ✅ |
| tipos do SELECT = esquema (dry-run) | ✅ |

Exemplos conferidos à mão (com link na tabela): [Pague Menos] Vinicius Nascimento (fim de semana, feriado de 12/10),
[Zoop] Zeca Camargo (retrabalho, reabertura, entrega sem Aguardando Feedback), [Amazon] Jeroan Herculano (clique
corrigido, alerta), [Ceraflame] Brissa Ioselli (Standby, em aberto), [Grupo BBM] Beatriz Reis (hora extra).

## 7. Limitações conhecidas

- O tempo é o do **card no monday**: se a equipe muda o status depois de fazer o trabalho, o tempo medido atrasa (L5).
- `orcamento` é o responsável **de hoje**, não o da época de cada passo (L4).
- Expediente igual para todos (10h–19h, RJ + SP); férias e ausências não entram (L6).
- O "Encerrado" automático (30 dias em Aguardando Feedback) não é um desfecho real da marca.
- Sub-status só existem desde 14/05/2026; antes, "Em Elaboração" genérico — comparar sub-status só daí em diante.
- O recorte muda com o tempo: um projeto que volta de Aguardando Feedback para a equipe sai da tabela até voltar.

## 8. Variações e próximos passos

- `gld_agenciamento_2026_sla_projetos` (rascunho em [`sql/rascunhos/`](../../sql/rascunhos/)): uma linha por projeto com
  os totais da equipe, do cliente e do Standby (R16). Não aprovada.
- Lacunas a resolver com a equipe (L1–L9) e melhorias de processo: [`docs/melhorias_processo.md`](../melhorias_processo.md).

## 9. Histórico

| Data | O que mudou |
|---|---|
| 21/10/2026 | Construção com o Caio: recorte (R1–R4, R11, R12), atributos e orçamento por nome (R5), histórico de status (R6–R10), tempo corrido e útil com calendário calculado por ano (R13, R14), fases (R15), em aberto e alerta (R17, R18), marcações do fluxo (R19), fora do expediente e hora extra (R20, R21), clique corrigido (R22) |
| 21/10/2026 | Implantação: tabela criada no BigQuery (validação 16/16), job `gold-agenciamento` agendado seg–sex 09:00, alerta testado |
| 22/10/2026 | Revisão do Codex, aprovada pelo Caio: R23 (sem `criado_em` não entra); R10 antes de R9/R22; 3 verificações novas. Comparado com a produção: histórico idêntico (14.838 linhas, 3.105 projetos, 0 diferenças). **Em produção** desde a execução `x4sl4` (19:08 Brasília), junto com a entrada diária, na mesma transação; validação 19/19 |
| 21/10/2026 | Revisão final: nome `gld_agenciamento_2026_sla_movimentos`; materialização como tabela; esquema em CSV com descrições; comando de criação gerado; validação com 16 verificações (16/16 OK); 1º passo robusto a evento antes da criação; calendário desde 2020 |

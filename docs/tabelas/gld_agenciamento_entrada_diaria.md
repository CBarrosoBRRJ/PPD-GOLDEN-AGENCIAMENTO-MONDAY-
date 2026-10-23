# `gold_monday.gld_agenciamento_entrada_diaria`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico. Os arquivos da tabela estão na linha **Arquivos**.

| | |
|---|---|
| **Situação** | 🚀 **em produção desde 22/10/2026** (criada 18:5x Brasília pelo `criar_…sql`, validação toda ok; 1ª carga pelo job às 19:08: 1.826 linhas); atualizada **seg–sex 09:00** pelo job `gold-agenciamento`, junto com a SLA, na mesma transação. **Saída** (`quantidade_saida`, R12–R15) em produção desde 23/10/2026 (coluna acrescentada por `ALTER TABLE`; carga `t89q9`: 2.333 linhas, 7.492 saídas). **Situação por safra** (`entregue_no_mes`, `entregue_depois`, `nao_seguiu`, `em_andamento`; R16–R20) em produção desde 23/10/2026 (colunas acrescentadas por `ALTER TABLE`; carga `ksw7n`: 2.333 linhas, 16 colunas). **Cadastro retroativo** (R21) em produção desde 23/10/2026 (carga `nlnzw`: 2.336 linhas; esquema igual, descrições atualizadas por `deploy/descrever_…sql`) |
| **Pergunta** | quantos pedidos entram e quantos são entregues ao cliente por dia no Agenciamento, por grupo de input e família; e o que aconteceu, até hoje, com os pedidos de cada safra (mês de entrada) |
| **Por que existe** | a diretoria pede previsão de demanda e um relatório por mês de entrada (entregue no próprio mês, depois, não seguiu, em andamento). O monday não guarda contagem por dia nem o destino dos cards de uma safra, e cada relatório refazia a conta pela `data_de_saida`, que é regravada a cada reenvio e faz um mês fechado mudar |
| **O que esperamos fazer** | série diária para os modelos de previsão (com e sem data estimada); relatório da diretoria por safra; acompanhamento de entregas por dia, grupo e família; base do site de relatórios (outro projeto). Mais de uma pergunta na mesma tabela, sem mexer no Power BI quando entra uma coluna |
| **Saída esperada** | uma linha por data × grupo × tipo × família, só quando há card, com 7 contagens: entrada real, entrada estimada, saída e as 4 de situação; de 2024-10-01 até ontem; ≈ 2.300 linhas; em toda execução os totais por ano são conferidos contra as silvers e a soma das 4 colunas de situação bate com as entradas em 100% das linhas |
| **Uma linha por** | data × `grupo_input` × `tipo_de_input` × `familia`, **só quando há entrada ou saída** (sem linhas com zero) |
| **Para que serve** | contagem diária de cards criados (entrada) e entregues ao cliente (saída) no Agenciamento (2024 a 2026) para análise de tendência e previsão de demanda, e a **situação hoje dos cards que entraram em cada dia** (safra) para o relatório da diretoria: por mês de entrada, quantos foram entregues no próprio mês, depois, não seguiram ou estão em andamento. Uma tabela só: os recortes (grupo, família, com ou sem estimados) e o calendário completo (dias com zero) são feitos por quem consome |
| **Quem usa** | modelos de previsão e o site de relatórios (outro projeto) |
| **Fontes** | `silver_monday.slv_agenciamento_2024_itens` e `slv_agenciamento_2025_itens` (boards históricos, **carga única** de 22/10/2026) e `silver_monday.slv_agenciamento_2026_itens` (diária, só `state = 'active'`); `silver_monday.slv_agenciamento_2026_log` (diária, mudanças de Status, para a saída — R12) |
| **Materialização** | tabela, cluster `data, grupo_input`, sem partição (≈ 2.300 linhas). Criada uma vez por `deploy/criar_…sql`; atualizada **seg–sex 09:00** pelo job `gold-agenciamento` (cresce um dia por execução). O job só exige a silver de 2026 do dia; 2024 e 2025 são carga única |
| **Arquivos** | SELECT [`sql/gld_agenciamento_entrada_diaria.sql`](../../sql/gld_agenciamento_entrada_diaria.sql) · esquema [`sql/esquemas/…csv`](../../sql/esquemas/gld_agenciamento_entrada_diaria.csv) · criação (gerada) [`deploy/criar_…sql`](../../deploy/criar_gld_agenciamento_entrada_diaria.sql) · validação [`sql/validacoes/…sql`](../../sql/validacoes/gld_agenciamento_entrada_diaria.sql) |
| **Custo** | ≈ 0,9 MB lidos por execução (dry-run de 22/10/2026; reserva Enterprise do projeto) |

## 1. Como ler

- **Total de cards num dia** = soma de `quantidade + quantidade_estimada` de todas as linhas da data.
- **Sem os estimados** = só `quantidade`. **Sem uma família** = filtrar `familia`. **Por grupo** = filtrar `grupo_input`.
- **Data de entrada** = criação real do card. No board 2026, um card cadastrado **depois** da entrega (cadastro
  retroativo, R21) entra pela `data_de_entrada` que a equipe preencheu, não pelo dia do cadastro.
- **Saídas num dia** = soma de `quantidade_saida`. É a **1ª entrega ao cliente** (1ª ida a Aguardando Feedback), não o
  encerramento: declinados e outros fechados sem entrega não têm saída.
- Uma linha pode ter só saída (`quantidade + quantidade_estimada = 0`) ou só entrada (`quantidade_saida = 0`).
- **Safra** (o que aconteceu com os cards que entraram): somar `entregue_no_mes`, `entregue_depois`, `nao_seguiu` e
  `em_andamento` pelas linhas do período de **entrada** (ex.: `ano = 2026 AND mes = 8`). As 4 somam
  `quantidade + quantidade_estimada` em toda linha; numa linha só com saída as 4 são 0. **Não** misturar com a
  `quantidade_saida` do mesmo dia: esta conta as entregas **feitas** no dia (de cards de qualquer safra); as 4 contam
  o destino dos cards que **entraram** no dia.
- **Foto do dia**: as 4 colunas mudam a cada execução — um card de setembro em andamento passa a entregue depois
  quando chega a Aguardando Feedback; um mês recente tem muito em andamento, que vai se resolvendo. Para comparar
  meses, olhar meses fechados (o em andamento deles fica pequeno: 0 a 4 por mês em jan–set/2026, em 23/10/2026). Quem
  quiser guardar a foto de uma data precisa copiar a tabela (aqui não há histórico das fotos).
- **Série contínua** (para modelos): completar o calendário de 2024-10-01 até ontem com 0 nos dias/combinações sem
  linha — a tabela não grava zeros.

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros` | início 2024-10-01; fim = ontem (Brasília); 5 dias úteis para a data estimada | R2, R4 |
| 2 | `anos`, `pascoa`, `feriados` | calendário sem expediente calculado por ano (o mesmo da SLA) | R3 |
| 3 | `aguardando_feedback` | 1ª ida a Aguardando Feedback de cada projeto do board 2026, pelo log | R12 |
| 4 | `itens` | os três boards no mesmo formato: data real (2024/2025 `criado_em`; 2026 `DATE(criado_em)` ou, no cadastro retroativo, `data_de_entrada`), `data_de_saida`, 1ª ida, tipo de input e de output, nome, marca, status; 2026 só ativos | R1, R5, R21 |
| 5 | `cards` | data do card (real; sem `criado_em`, estimada = `data_de_saida` − 5 dias úteis); saída válida (1ª ida pelo log, senão `data_de_saida`; antes da data de entrada não vale); nome e marca sem acento e minúsculos | R1, R2, R8, R12–R14 |
| 6 | `classificados` | situação hoje do card (no mês, depois, não seguiu, em andamento); grupo de input; família, com prioridade | R7–R9, R16–R18 |
| 7 | `eventos` | cada card vira até dois eventos: a **entrada** na data do card (leva as 4 marcas de situação) e a **saída** na data da saída válida; só eventos dentro do período | R4, R6, R15, R19 |
| 8 | SELECT final | soma por data × grupo × tipo × família; colunas de calendário; só combinações com card | R10, R11, R20 |

Como cada número nasce (um card conta no máximo uma vez em cada coluna):

| Coluna | Cálculo |
|---|---|
| `data` | a data do evento: do card (entrada) ou da saída válida (saída) |
| `quantidade` | cards com data real cuja data do card = `data` |
| `quantidade_estimada` | cards sem `criado_em`, com data estimada = `data` |
| `quantidade_saida` | cards cuja saída válida = `data`, de qualquer safra |
| `entregue_no_mes` | dos cards de `quantidade + quantidade_estimada`: saída válida até ontem e `DATE_TRUNC(saida, MONTH) <= DATE_TRUNC(data, MONTH)` |
| `entregue_depois` | dos mesmos: saída válida até ontem, em mês posterior ao da `data` |
| `nao_seguiu` | dos mesmos: sem saída válida até ontem e status atual `Declinado…`, `Standby` ou `Encerrado` |
| `em_andamento` | dos mesmos: o resto (inclusive status vazio) |

Exemplo (card real do board 2026, cadastro retroativo): criado em 07/10/2026, `data_de_entrada` 15/04/2026,
`data_de_saida` 20/04/2026, status Encerrado, sem ida a Aguardando Feedback no log. **Sem a R21**: entrada em
07/10/2026; saída inválida (20/04 é antes da criação, R14); `nao_seguiu` em outubro. **Com a R21**: entrada em
15/04/2026; saída 20/04/2026 válida; `entregue_no_mes` em abril, e `quantidade_saida` em 20/04.

## 3. Colunas (16)

| # | Coluna | Tipo | Origem | Regra |
|---|---|---|---|---|
| 1 | `data` | DATE | dia da entrada (`criado_em`; `data_de_entrada` no cadastro retroativo; estimada pela `data_de_saida`) ou da saída dos cards contados na linha | R1–R6, R12–R15, R21 |
| 2 | `dia_semana` | STRING | `data` (seg, ter, qua, qui, sex, sáb, dom) | R11 |
| 3 | `ano` | INT64 | `data` | R11 |
| 4 | `mes` | INT64 | `data` (1–12) | R11 |
| 5 | `inicio_semana` | DATE | segunda-feira da semana da `data` | R11 |
| 6 | `grupo_input` | STRING | `tipo_de_input` | R7 |
| 7 | `tipo_de_input` | STRING | silver, como vem; vazio = `Sem tipo` | R7 |
| 8 | `familia` | STRING | nome do projeto, marca e `tipo_de_output` | R8, R9 |
| 9 | `quantidade` | INT64 | cards com data real | R1, R21 |
| 10 | `quantidade_estimada` | INT64 | cards com data estimada | R2 |
| 11 | `quantidade_saida` | INT64 | cards entregues ao cliente no dia | R12–R15 |
| 12 | `entregue_no_mes` | INT64 | dos cards que entraram na linha: saída válida no mesmo mês-calendário da entrada | R16, R19, R20 |
| 13 | `entregue_depois` | INT64 | dos cards que entraram na linha: saída válida em mês posterior | R16, R19, R20 |
| 14 | `nao_seguiu` | INT64 | dos cards que entraram na linha: sem saída, status Declinado (qualquer), Standby ou Encerrado | R17, R19, R20 |
| 15 | `em_andamento` | INT64 | dos cards que entraram na linha: os demais | R18, R19, R20 |
| 16 | `_processado_em` | TIMESTAMP | execução | — |

Em produção, as colunas acrescentadas por `ALTER TABLE` (`quantidade_saida` e as 4 de situação) ficam **depois** de
`_processado_em` no esquema; o job grava pelo nome, então a ordem não importa. Quem lê deve usar o nome da coluna.

## 4. Regras

### 4.1 Data

| ID | Regra | Decidido em |
|---|---|---|
| R1 | **Data real** = `criado_em` (DATE) em 2024 e 2025; `DATE(criado_em)` em 2026 (ou a `data_de_entrada`, no cadastro retroativo — R21). **Nunca** o `created_at` de 2024/2025: é a data da importação (03/09/2026). Conta em `quantidade` | Caio, 22/10/2026 |
| R2 | **Sem `criado_em` e com `data_de_saida`** (qualquer board) → data estimada = `data_de_saida` − **5 dias úteis** (parâmetro `dias_uteis_estimativa`). Conta em `quantidade_estimada`. **Sem as duas datas** → fora da tabela (vai ao log) | Caio, 22/10/2026 |
| R3 | **Dia útil** = seg–sex fora do calendário sem expediente da `gld_agenciamento_2026_sla_movimentos` (R14 de lá: fixos nacionais, RJ, SP e vésperas; Carnaval, Cinzas, Sexta-feira Santa e Corpus Christi pela Páscoa). O calendário está **copiado igual** no SELECT da SLA, neste SELECT e na validação desta tabela: mudar nos três juntos | Caio, 22/10/2026 |
| R4 | **Período**: de **2024-10-01 até ontem** (Brasília). Antes disso fica fora (vai ao log): jun–set/2024 tem ~12 cards em 4 meses e ensinaria um crescimento falso. Hoje não entra (dia ainda aberto) | Caio, 22/10/2026 |
| R5 | Board 2026 só `state = 'active'` | Caio, 22/10/2026 |
| R6 | **Conta pela data, não pelo board**: card do board 2024 com data de 2025 conta em 2025, e vice-versa; card do board 2026 com entrada corrigida para 2025 (R21) conta em 2025 | Caio, 22/10/2026 |
| R21 | **Cadastro retroativo (só board 2026)**: card com `data_de_saida` **antes** da criação e `data_de_entrada` preenchida **até** a `data_de_saida` → a data de entrada do card é a **`data_de_entrada`**, não o `criado_em`. Vale para `quantidade` e para as 4 colunas de situação; a saída é validada contra a data corrigida (R14) e passa a valer normalmente. **Motivo:** a equipe cadastrou de uma vez, em outubro/2026, cards já entregues meses antes — 79 em 07/10/2026, com `data_de_entrada` de dez/2025 a jul/2026 — e eles inflavam outubro (600 cards) e o "não seguiu" de outubro (164, quase todos Encerrado sem saída válida). Em 23/10/2026 a regra corrige **154** cards (93 criados em outubro, 61 em outros meses de 2026); 9 vão para out–dez/2025. Sem `data_de_entrada`, ou com ela depois da `data_de_saida` (37 cards em 23/10/2026), nada muda: entra pelo `criado_em`; a saída só vale se a 1ª ida a Aguardando Feedback pelo log for depois da criação (10 dos 37); os outros 27 ficam sem saída (R14). A regra lê a `data_de_saida` **atual**: uma reentrega a regrava para depois da criação e a condição deixa de valer (ver pontos de atenção). Nos boards 2024/2025 a regra não se aplica (sem caso e sem log para conferir). O log do job registra, por ano de entrada, quantos cards foram corrigidos | Caio, 23/10/2026 |

### 4.2 Grupo de input

| ID | Regra | Decidido em |
|---|---|---|
| R7 | `grupo_input`: **Mercado**, **Inbound**, **Proativo** (o próprio tipo); **Internos** = ViU, Interna, Globo, ViU First, OTR (Oportunidade em Tempo Real); **Sem tipo** = `tipo_de_input` vazio. Tipo novo que apareça no board cai em **Outros** (não trava o job); quando houver, o log da execução registra um aviso **WARNING** com os valores novos de `tipo_de_input` e os cards de cada um (hoje nenhum) — decidir o grupo e incluir na lista | Caio, 22/10/2026 |

### 4.3 Família

| ID | Regra | Decidido em |
|---|---|---|
| R8 | **Marca, não filtra**: todo card entra; `familia` só identifica. **Mesmo método nos três anos**, o da silver (`regras.familias_do_nome` e `eh_upfront` do PPD-SILVER-MONDAY), sobre o texto sem acento e minúsculo: **Upfront** = "upfront" no nome **ou na marca**, ignorando espaços e símbolos ("Upfront 27", "UPFRONT2027"); **Levop** `\blevop\b`, **Mídia Kit** `\b(midia\|media)[ _-]*kits?\b`, **Análise** `\b(analises?\|abalise\|aalise)\b`, **Defesa** `\bdefesas?\b`, **Curadoria** `\bcurador(ias?\|as?\|es)?\b` — no nome, palavra inteira. Pelo **tipo de output** (os 3 que a SLA exclui): `Levop \| Card de Oportunidade \| Informação por e-mail` → **Card de Oportunidade (Levop)**; `Curadoria Orçada` → **Curadoria Orçada**; `Defesas \| Estudo Comercial \| Curadorias` → **Defesas \| Estudo Comercial**. **De-para das variantes antigas** de tipo de output (boards 2024/2025), para a regra ser igual nos três anos: `Levop \| Boletim Informativo/Boletim de efeméride` → **Levop**; `Midia Kits` → **Mídia Kit**; `Defesa \| Análise \| Estudo Comercial` → **Defesas \| Estudo Comercial**. Nenhuma = **Nenhuma**. **Não** usa as colunas TRUE/FALSE da silver de 2026 (não existem em 2024 e 2025): a busca acha 199 dos 206 marcados pela silver em 2026 (Mercado/Inbound); perder 7 é melhor que misturar critérios. As outras colunas TRUE/FALSE (`exclusivo`, `vendido`, `produto_globo`, divergências, pendências) não entram | Caio, 22/10/2026 |
| R9 | **Prioridade** (card com mais de uma família fica com a primeira): **1 Upfront → 2 Levop → 3 Mídia Kit → 4 Análise → 5 Defesa → 6 Curadoria → 7 Card de Oportunidade (Levop) → 8 Curadoria Orçada → 9 Defesas \| Estudo Comercial**. Motivo: o nome do projeto é mais específico que o tipo de output (quase todas as sobreposições são o mesmo projeto pelos dois lados, ex.: "Curadoria" no nome + output "Curadoria Orçada"); Upfront é o evento que contém cotas de Levop e Curadoria ("Upfront 2027 \| Levop Cota Protagonista"); Mídia Kit antes de Análise (a Análise acompanha o Mídia Kit); Curadoria por último entre as do nome por ser a mais ampla. As variantes antigas de output (R8) entram na posição das saídas por output, depois das 6 do nome | proposta do Claude, **aprovada pelo Caio** em 22/10/2026 |
| R10 | Só as combinações com card: sem linhas com zero (quem consome completa o calendário) | Caio, 22/10/2026 |
| R11 | Colunas de calendário da `data`: `dia_semana` (abreviado em português), `ano`, `mes` e `inicio_semana` (segunda-feira; `DATE_TRUNC(data, ISOWEEK)`). Sem número de semana: a semana ISO confunde na virada do ano; para somar por semana, agrupar por `inicio_semana` | Caio, 22/10/2026 |

Sobreposições em 22/10/2026 (189 cards com mais de uma família): Curadoria + Curadoria Orçada 79; Defesa + Defesas \|
Estudo Comercial 37; Curadoria + Defesas \| Estudo Comercial 33; Upfront + Levop 20; Upfront + Levop + Card de
Oportunidade 8; Levop + Card de Oportunidade 5; Defesa + Card de Oportunidade 4; Curadoria + Card de Oportunidade 2;
Upfront + Curadoria + Defesas \| Estudo Comercial 1.

### 4.4 Saída

| ID | Regra | Decidido em |
|---|---|---|
| R12 | **Saída = 1ª entrega ao cliente.** Board 2026: data da **1ª entrada em Aguardando Feedback** no log (`campo_alterado = 'Status'`, `valor_depois = 'Aguardando Feedback'`). Motivo: a `data_de_saida` é preenchida por automação a cada ida a Aguardando Feedback e **regravada nas reentregas** (437 cards em 23/10/2026 com a data da última ida); a 1ª ida pelo log não muda depois de gravada, então um mês fechado não muda sozinho. Boards 2024 e 2025: `data_de_saida` (não há log) | Caio, 23/10/2026 (opção B) |
| R13 | Board 2026 **sem Aguardando Feedback no log** (ou só antes da criação) → `data_de_saida` (70 cards em 23/10; 193 com a R21, que valida a `data_de_saida` dos cadastros retroativos) | Caio, 23/10/2026 |
| R14 | **Saída antes da data de entrada não vale**: a do log antes da entrada cai para a `data_de_saida`; esta também antes da entrada → card **fora das saídas** (a entrada dele continua), contado no log do job. Ex.: 41 cards do board 2026 com `data_de_saida` antes da criação ficam com a data do log; fora: 150 (2026), 16 (2025) e 1 (2024) em 23/10/2026 — com a R21, 27 em 2026 | Caio, 23/10/2026 |
| R15 | `quantidade_saida` com o mesmo período (R4: de 2024-10-01 até ontem; saída futura entra quando chegar), o mesmo `grupo_input` e a mesma `familia` do card (R7–R9); conta pela data, não pelo board (R6). Linha existe quando há entrada **ou** saída (R10). Fechados sem entrega (declinados) **não** entram | Caio, 23/10/2026 |

### 4.5 Situação por safra

| ID | Regra | Decidido em |
|---|---|---|
| R16 | **Entregue**: card com **saída válida** — exatamente a da `quantidade_saida` (R12–R14: 1ª ida a Aguardando Feedback pelo log no board 2026; `data_de_saida` em 2024/2025 e quando falta o log; saída antes da entrada não vale) **até ontem** (R4/R15; saída futura ainda não aconteceu). `entregue_no_mes` = saída no mesmo mês-calendário da data de entrada; `entregue_depois` = em mês posterior. Saída em mês **anterior** ao da entrada (só possível em card de data estimada) conta como no mês — 0 casos em 23/10/2026 | Caio, 23/10/2026 |
| R17 | **Não seguiu**: sem saída válida e **status atual** `Declinado …` (qualquer variante: Internamente, pelo Mercado, pelo talento), `Standby` ou `Encerrado`. Status atual = o da silver do board de origem do card; board 2026 só `state = 'active'` (R5). Encerrado sem saída é pendência de preenchimento do board (vai ao log) | Caio, 23/10/2026 |
| R18 | **Em andamento**: todos os demais (Entrada, Em elaboração …, Em revisão …, Aguardando Feedback sem saída válida, status vazio) | Caio, 23/10/2026 |
| R19 | **Safra = data de entrada da linha** (`data` dos cards de `quantidade` e `quantidade_estimada`; o estimado usa a data estimada, R2; o cadastro retroativo usa a `data_de_entrada`, R21). As 4 colunas ficam nas linhas de entrada; linha só com saída tem as 4 = 0 | Caio, 23/10/2026 |
| R20 | `entregue_no_mes + entregue_depois + nao_seguiu + em_andamento = quantidade + quantidade_estimada` em **toda** linha (trava da validação). As colunas são uma **foto do dia** e mudam a cada execução; `quantidade`, `quantidade_estimada` e `quantidade_saida` não mudam por causa delas | Caio, 23/10/2026 |

## 5. Log de cada execução

As linhas "informativo" da validação vão ao log do job (Cloud Logging, mensagem "validação", severidade INFO): cards
fora por estarem antes de 2024-10-01; cards fora por não terem data (por board); cards com data estimada; totais por
ano; total por família por ano; e, da situação por safra, por ano de entrada: total de cada uma das 4 colunas,
**Encerrado sem saída válida** (pendência de preenchimento do board), **em andamento com entrada há mais de 60 dias**
e **cards com a data de entrada corrigida pelo cadastro retroativo** (R21); agosto/2026, 2026 por mês (total e não
seguiu) e o em andamento por mês de jan–set/2026. Avisos (WARNING, não bloqueiam): anos fora da referência de
23/10/2026 com a R21 (entradas 328 / 3.586 / ≥ 5.520, saídas 204 / 3.020 / ≥ 4.391) e mês fechado de 2026 (jan–set)
com mais de 20 em andamento. A linha "aviso" (tipos de input novos, grupo Outros) vai como **WARNING** quando tem
valores (`job/main.py`: `esperado = 'aviso'` e resultado diferente de `0`); não bloqueia a gravação.

## 6. Validação e números

Ensaio de 22/10/2026, depois da revisão do Codex (SELECT validado direto, sem gravar): **todas ok** (7 verificações,
as informativas e 1 aviso). A recontagem nas silvers é independente do SELECT: acha a data estimada por dias úteis
numerados em sequência (o último antes da saída é o nº n; a data é o nº n − 4), com o calendário estendido até a maior
`data_de_saida` dos cards a estimar (a saída pode ser futura), com teto de hoje + 60 dias (uma data absurda não
explode o calendário; cards a estimar além do teto viram aviso), e compara **dia a dia**, reais e estimados separados. O grupo é conferido
contra o mapa tipo → grupo escrito de novo na validação.

**Referências** (decisão do Caio, 22/10/2026): a trava fixa é **por board histórico** — cards dos boards 2024 e 2025
com data (real ou estimada) desde 2024-10-01, **sem o limite "até ontem"**: **327** e **3.578**. Só mudam se a silver
histórica for recarregada; um card do board 2026 que caia em 2025 não a afeta, e o passar dos dias também não
(conferido em 22/10/2026: nenhum card histórico tem data de hoje em diante — maior saída do board 2025 é 07/01/2026). Os totais por ano de 22/10/2026 — **328 (2024), 3.577 (2025), 5.488 (2026)** — ficam como
informativo; a tabela é conferida contra a recontagem nas silvers, que acompanha o crescimento de 2026.

| Verificação | Resultado |
|---|---|
| chave data × grupo_input × tipo_de_input × familia única | 0 repetidas (≈ 1.825 linhas) |
| datas antes de 2024-10-01 ou depois de ontem | 0 |
| linhas inválidas (vazio, negativo, linha sem card, `dia_semana`/`ano`/`mes`/`inicio_semana` errados) | 0 |
| grupo_input incoerente com o tipo_de_input (R7) | 0 |
| por ano: `quantidade` + `quantidade_estimada` = silvers pela data | 2024: 317 + 11 = 328 · 2025: 3.001 + 576 = 3.577 · 2026: 5.483 + 5 = 5.488 |
| `quantidade` e `quantidade_estimada` = recontagem, dia a dia | 0 dias diferentes (reais e estimados) |
| referência por board histórico | board 2024: 327 · board 2025: 3.578 |
| informativo: totais por ano | 328 · 3.577 · 5.488 |
| informativo: fora antes de 2024-10-01 / sem data | 12 / 2024: 13 · 2025: 149 |
| informativo: estimados | 592 |
| aviso: tipos de input novos (Outros) | nenhum |

Origem da referência (diferença para os 317 / 3.577 / 5.483 da `demanda_diaria`, que estimava só o board 2025): a R2
vale para os três boards, e entram **16 estimados a mais** — 11 do board 2024 (sem `criado_em`, com `data_de_saida`;
dos 24 sem data, agora só 13 ficam fora) e 5 do board 2026 (os 5 ativos sem `criado_em`). Os cards com data real
batem: 317 (2024) e 5.483 (2026); 2025 tem 3.001 reais (3.002 do board 2025 − 9 com data de 2024 + 8 do board 2024
com data de 2025).

Total por família por ano (real + estimada):

| Família | 2024 | 2025 | 2026 |
|---|---|---|---|
| Nenhuma | 313 | 3.377 | 4.914 |
| Upfront | — | 78 | 150 |
| Levop | 12 | 1 | 4 |
| Mídia Kit | — | 10 | 9 |
| Análise | — | 8 | 6 |
| Defesa | 1 | 8 | 34 |
| Curadoria | 2 | 40 | 205 |
| Card de Oportunidade (Levop) | — | 38 | 103 |
| Curadoria Orçada | — | — | 56 |
| Defesas \| Estudo Comercial | — | 17 | 7 |

Por grupo (linhas · real + estimada): Mercado 574 · 4.331 + 251; Inbound 480 · 2.400 + 158; Internos 481 · 1.131 + 86;
Proativo 246 · 857 + 97; Sem tipo 44 · 82 + 0.

### 6.1 Situação por safra (ensaio de 23/10/2026, SELECT validado direto, sem gravar)

Toda validação ok: soma das 4 colunas = `quantidade + quantidade_estimada` em 100% das linhas (0 diferentes);
recontagem independente nas silvers (mês por `FORMAT_DATE`, status por `LIKE`) com **0 dias diferentes**; nenhuma
chave repetida, nenhum nulo ou negativo; entradas por ano inalteradas (328 / 3.577 / 5.529) e saídas também
(204 / 3.012 / 4.276); travas por board inalteradas (327 / 3.578 e 213 / 3.005).

| Ano de entrada | Entradas | No mês | Depois | Não seguiu | Em andamento | Encerrado sem saída | Em andamento > 60 dias |
|---|---|---|---|---|---|---|---|
| 2024 | 328 | 182 | 30 | 105 | 11 | 23 | 11 |
| 2025 | 3.577 | 2.226 | 777 | 572 | 2 | 66 | 2 |
| 2026 | 5.529 | 3.643 | 631 | 1.095 | 160 | 161 | 8 |

Em andamento por mês de entrada em 2026 (meses fechados): jan 1 · fev 0 · mar 1 · abr 0 · mai 0 · jun 1 · jul 2 ·
ago 3 · set 4 (referência 0 a 20). Outubro (aberto): 600 entradas, 148 em andamento.

**Agosto/2026: 640 = 486 no mês + 50 depois + 101 não seguiu + 3 em andamento.** A referência pela coluna
`data_de_saida` era ≈ 462 / 76 / 97 / 5. Refeita aqui pela coluna, com a mesma regra de status: 462 / 76 / 99 / 3.
Da coluna para a regra B:

- **+31 no mês, −31 depois**: 1ª entrega em agosto, mas a `data_de_saida` foi regravada numa reentrega em setembro
  ou outubro (a coluna guarda a última ida ao cliente);
- **−5 no mês, +5 depois**: `data_de_saida` em agosto, mas a 1ª ida a Aguardando Feedback pelo log só em setembro
  (data preenchida antes da mudança de status);
- **−2 no mês, +2 não seguiu**: `data_de_saida` antes da criação e sem ida no log — saída inválida (R14); status
  Declinado Internamente e Encerrado.

A diferença de 2 entre 97 / 5 e 99 / 3 (não seguiu / em andamento) já aparece pela própria coluna: provavelmente
status lido em outro momento (2 cards que saíram de "em elaboração" para Standby, Declinado ou Encerrado) ou outra
lista de status; não dá para refazer a referência exata.

### 6.2 Cadastro retroativo (ensaio de 23/10/2026, SELECT validado direto, sem gravar)

Toda validação ok: soma das 4 colunas = entradas em 100% das linhas; recontagem independente (com a R21 escrita de
novo) com 0 dias diferentes em entradas, saídas e situação; nenhuma chave repetida, nenhum nulo ou negativo; travas por
board inalteradas (327 / 3.578 e 213 / 3.005). **154 cards corrigidos**, por ano de entrada: 2025: 9 · 2026: 145.

| | Antes (carga `ksw7n`) | Com a R21 | Diferença |
|---|---|---|---|
| Entradas 2024 / 2025 / 2026 | 328 / 3.577 / 5.529 | 328 / **3.586** / **5.520** | 9 cards com `data_de_entrada` em 2025: 8 criados em jan/2026 (3 → out/2025, 5 → dez/2025) e 1 criado em out/2026 (→ dez/2025); R6: conta pela data |
| Saídas 2024 / 2025 / 2026 | 204 / 3.012 / 4.276 | 204 / **3.020** / **4.391** | 123 saídas que eram "antes da criação" passam a valer (2026: 150 → 27 fora) |
| Situação 2025 (no mês · depois · não seguiu · andamento) | 2.226 · 777 · 572 · 2 | 2.231 · 781 · 572 · 2 | |
| Situação 2026 | 3.643 · 631 · 1.095 · 160 | 3.710 · 678 · **972** · 160 | 123 cards saem de não seguiu para entregue |
| Encerrado sem saída válida (2024 / 2025 / 2026) | 23 / 66 / 161 | 23 / 66 / **48** | 113 dos 161 eram cadastro retroativo |
| Outubro/2026: total e não seguiu | 600 e 164 | **508** e **74** | pedido: ≈ 510 e ≈ 70 |

Por mês de entrada (total antes → depois; cards corrigidos que caem no mês): out/2025 456 → 459 (3) · dez/2025
182 → 188 (6) · jan/2026 372 → 374 (10) · fev 338 → 341 (4) · mar 474 → 485 (12) · abr 447 → 472 (42) · mai 610 → 629 (22) ·
jun 541 → 569 (29) · jul 772 → 765 (13) · ago 640 → 644 (8) · set 735 → 733 (4) · out 600 → 508 (1). Os números entre parênteses
são por mês da entrada **corrigida** (destino), não por mês de criação. Julho e setembro **caem** porque cards
criados neles também eram cadastro retroativo de meses anteriores (julho tinha 20 corrigíveis criados lá e recebe
13); janeiro perde 8 para out–dez/2025 e recebe 10. A soma das diferenças é 0: neste ensaio nenhum card entra ou sai
da tabela, só muda de dia (uma `data_de_entrada` antes de 2024-10-01 tiraria o card do período — 0 casos). Agosto/2026 passa a 644 = 489 + 51 + 101 + 3.

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Situação é foto do dia | as 4 colunas de safra mudam a cada execução; meses recentes têm muito em andamento. A diretoria deve olhar meses fechados ou guardar a foto da data do relatório |
| Cadastro retroativo (R21) depende da `data_de_entrada` | a correção só acontece quando a equipe preenche a `data_de_entrada` até a `data_de_saida`. Card cadastrado depois da entrega **sem** essa data, ou com ela depois da saída (37 cards em 23/10/2026), continua no dia do cadastro; sem ida a Aguardando Feedback no log depois da criação fica sem saída (27 dos 37) e aparece como "não seguiu" no mês do cadastro. **Reentrega desfaz a correção:** a R21 lê a `data_de_saida` atual, que a automação regrava a cada ida a Aguardando Feedback; se um card corrigido for reenviado, a `data_de_saida` passa a ser depois da criação, a condição deixa de valer e o card volta para o mês do cadastro, com a saída nova (0 casos em 23/10/2026; decisão pendente do Caio — apontado pelo Codex). Pedir à equipe: cadastro em lote com `data_de_entrada` e `data_de_saida` preenchidas. A silver traz `criador_nome` vazio em 78 dos 79 cards de 07/10/2026, então não dá para confirmar pelos dados quem cadastrou |
| Encerrado sem saída (`nao_seguiu`) | 23 / 66 / 48 por ano de entrada (com a R21): cards encerrados sem ida a Aguardando Feedback nem `data_de_saida` válida. Podem ser entregas que não passaram pelo status — pendência de preenchimento no board; contam como não seguiu |
| Status atual de 2024/2025 | vem da carga única dos boards históricos e não muda mais. Os 11 (2024) e 2 (2025) em andamento são cards parados nesses boards |
| Efeito do de-para das variantes antigas (R8) | só o Levop mudou: +12 cards em 2024 (Boletim Informativo; os outros 6 dos 18 são de antes de 2024-10-01 ou sem data). Os 16 "Midia Kits" de 2025 e o "Defesa \| Análise \| Estudo Comercial" de 2024 já caíam numa família pelo nome, ou ficam fora do período |
| out/2024 ainda fraco (74 cards) contra nov/2024 (129) | o Caio testa o modelo começando em out e em nov/2024 |
| Mudança de patamar 2025 → 2026 (Mercado +145% na média mensal) | tendência real ou mudança de uso do board |
| Saída em 2024 e 2025 vem da coluna (R12) | esses boards não têm log, então a B usa a `data_de_saida`. **Nesses anos, um reenvio pode ter movido a data de saída** para o dia da última ida ao cliente; não há como recuperar a 1ª. No board 2026 (com log) isso aconteceu em 437 dos 4.204 cards com saída pelo log (10%), com mediana de 8 dias (23/10/2026); a série muda de método em jan/2026 |
| Difere de relatórios feitos pela coluna | quem conta saídas pela `data_de_saida` vai achar números diferentes por causa dos reenvios: a tabela conta a 1ª entrega e a coluna guarda a última. Ex.: agosto/2026 = 561 aqui (Proativo 34) e 567 pela coluna (Proativo 54). O log do job mostra, por ano, quantos cards tiveram a `data_de_saida` regravada depois da 1ª entrega |
| Saída do board 2026 que vem da coluna (R13; 193 cards com a R21) | pode mudar se a equipe editar a `data_de_saida`; as que vêm do log ficam fixas |
| O que muda um número já gravado | card excluído no monday (sai da contagem), card que muda de tipo de input ou de nome/família (muda de linha; o total do dia fica), edição da `data_de_entrada` ou da `data_de_saida` de um cadastro retroativo (R21) e recarga da silver. A 1ª ida a Aguardando Feedback em si não muda |
| Picos de saída | entregas em lote no mesmo dia (ex.: 16/10/2026, 20 Curadorias de Mercado) |
| Saída não é encerramento | declinados e standby quase nunca têm entrega; para fluxo de encerramento seria outra coluna (só 2026, pelo log) |

## 8. Histórico

| Data | O que mudou |
|---|---|
| 22/10/2026 | Ensaios da `gld_agenciamento_demanda_diaria` (uma linha por dia, calendário contínuo; nunca criada no BigQuery) substituídos por esta tabela, por ordem do Caio: uma tabela só, grão data × grupo × tipo × família, sem zeros, famílias marcadas (não filtradas) pelo mesmo método nos três anos, estimativa para todos os boards. Validação 20/20 sem gravar |
| 22/10/2026 | **Aprovada pelo Caio** com ajustes: prioridade R9 aprovada; de-para das variantes antigas de output (R8); aviso WARNING para tipos novos (R7, `job/main.py`); referência 328 / 3.577 / 5.488; colunas de calendário `dia_semana`, `ano`, `mes`, `inicio_semana` (R11). Validação 22/22 sem gravar |
| 22/10/2026 | Revisão do Codex: validação com calendário até a maior saída (saída futura), conferência dia a dia de reais e estimados, mapa tipo → grupo; trava fixa por board histórico (327 / 3.578) no lugar da por ano (decisão do Caio); job grava as tabelas tudo ou nada. Validação toda ok sem gravar |
| 22/10/2026 | 2ª revisão do Codex (apto para implantar): calendário da validação com teto de hoje + 60 dias e só sobre cards a estimar; trava por board sem o limite "até ontem"; aviso para saída além do teto; job com ROLLBACK explícito. Validação toda ok sem gravar |
| 22/10/2026 | **Implantada** pelo Caio (Cloud Shell, a partir do commit `75bbf3c`): tabela criada e validada, permissões, job reimplantado com as duas tabelas, ensaio `rkwp9` e carga real `x4sl4` (19:08 Brasília, 1.826 linhas) |
| 23/10/2026 | **Saída** construída com o Caio (R12–R15, opção B: 1ª ida a Aguardando Feedback pelo log no board 2026; `data_de_saida` em 2024/2025 e como reserva). Coluna nova `quantidade_saida`; linhas com só saída. Ensaio sem gravar: entradas idênticas às de produção (8.842 + 592), saídas 2024: 204 · 2025: 3.012 · 2026: 4.276, recontagem dia a dia 0 diferenças, trava das saídas por board 213 / 3.005; toda validação ok. Aprovada pelo Caio (B), com as limitações de 2024/2025 e o log de `data_de_saida` regravada (437 em 2026) e de Declinado pelo Mercado sem saída (9 / 48 / 112) |
| 23/10/2026 | **Implantada** pelo Caio (Cloud Shell, commit `0c10d28`): `ALTER TABLE ... ADD COLUMN quantidade_saida`, job reimplantado (agendamento mantido), ensaio `gsxdq` (toda validação ok, sem WARNING) e carga real `t89q9` (14:22 Brasília: 2.333 linhas, 8.842 + 592 entradas, 7.492 saídas) |
| 23/10/2026 | **Situação por safra** (R16–R20), pedida pelo Caio: `entregue_no_mes`, `entregue_depois`, `nao_seguiu`, `em_andamento` (INT64, foto do dia), mesmo grão; validação com a soma, recontagem dia a dia, referência por ano e meses fechados, e log por ano (4 colunas, Encerrado sem saída, em andamento > 60 dias). Ensaio sem gravar: toda validação ok; agosto/2026 640 = 486 + 50 + 101 + 3 |
| 23/10/2026 | **Implantada** pelo Caio (Cloud Shell, commit `33d3107`): `ALTER TABLE ... ADD COLUMN` das 4 colunas, job reimplantado, ensaio `gold-agenciamento-r57ct` (dry-run, toda validação ok, sem WARNING) e carga real `gold-agenciamento-ksw7n` (15:05 Brasília: 2.333 linhas, 16 colunas; safra 6.051 no mês + 1.438 depois + 1.772 não seguiu + 173 em andamento = 9.434 entradas; SLA 14.873 linhas, 3.114 projetos) |
| 23/10/2026 | **Cadastro retroativo** (R21), pedido pelo Caio: no board 2026, card com `data_de_saida` antes da criação e `data_de_entrada` até a `data_de_saida` entra pela `data_de_entrada`; a saída passa a valer. Sem coluna nova. Validação: recontagem com a R21 escrita de novo; referência por ano atualizada (3.586 / ≥ 5.520 entradas, 3.020 / ≥ 4.391 saídas); log por ano dos cards corrigidos e 2026 por mês. Ficha reescrita como PRD da tabela (pergunta, por quê, saída esperada, memória de cálculo). Ensaio sem gravar: toda validação ok; 154 cards corrigidos; outubro/2026 600 → 508 e não seguiu 164 → 74 |
| 23/10/2026 | Auditoria do Codex (só leitura, reproduziu os números): apto para implantar. Corrigido: a ficha dizia que os 37 não corrigíveis ficam sem saída (10 têm saída válida pelo log; 27 não) e atribuía os 9 cards de 2025 a janeiro (8 criados em janeiro, 1 em outubro); descrição de `quantidade_saida` ("antes da criação" → "antes da data de entrada"), rótulo `antes da entrada` na validação, R12 com 437 reenvios; `deploy/descrever_…sql` gerado para atualizar descrições sem recriar a tabela. Anotado como pendência: reconciliação só por dia (não pelo grão completo). Decisão pendente do Caio: reentrega de card corrigido o devolve ao mês do cadastro |
| 23/10/2026 | **Implantado** pelo Caio em 23/10/2026 (Cloud Shell, commit `da661ef`): descrições atualizadas por `deploy/descrever_…sql` (a 1ª tentativa, com 17 instruções, parou na cota de metadado do BigQuery — 5 por tabela a cada 10 s; o gerador passou a juntar as colunas numa instrução), job reimplantado, ensaio `gold-agenciamento-bzhhb` (dry-run, toda validação ok, sem WARNING) e carga real `gold-agenciamento-nlnzw` (16:18 Brasília: 2.336 linhas, 16 colunas; entradas 328 / 3.586 / 5.520; saídas 204 / 3.020 / 4.391; outubro/2026 508 = 286 + 0 + 74 + 148; agosto/2026 644 = 489 + 51 + 101 + 3; SLA 14.873 linhas, 3.114 projetos) |

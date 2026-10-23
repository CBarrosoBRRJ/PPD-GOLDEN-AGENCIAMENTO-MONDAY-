# `gold_monday.gld_agenciamento_entrada_diaria`

| | |
|---|---|
| **Situação** | 🚀 **em produção desde 22/10/2026** (criada 18:5x Brasília pelo `criar_…sql`, validação toda ok; 1ª carga pelo job às 19:08: 1.826 linhas); atualizada **seg–sex 09:00** pelo job `gold-agenciamento`, junto com a SLA, na mesma transação. **Saída** (`quantidade_saida`, R12–R15) construída e validada sem gravar em 23/10/2026; aguarda aprovação e implantação (coluna nova) |
| **Uma linha por** | data × `grupo_input` × `tipo_de_input` × `familia`, **só quando há entrada ou saída** (sem linhas com zero) |
| **Para que serve** | contagem diária de cards criados (entrada) e entregues ao cliente (saída) no Agenciamento (2024 a 2026) para análise de tendência e previsão de demanda. Uma tabela só: os recortes (grupo, família, com ou sem estimados) e o calendário completo (dias com zero) são feitos por quem consome |
| **Quem usa** | modelos de previsão e o site de relatórios (outro projeto) |
| **Fontes** | `silver_monday.slv_agenciamento_2024_itens` e `slv_agenciamento_2025_itens` (boards históricos, **carga única** de 22/10/2026) e `silver_monday.slv_agenciamento_2026_itens` (diária, só `state = 'active'`); `silver_monday.slv_agenciamento_2026_log` (diária, mudanças de Status, para a saída — R12) |
| **Materialização** | tabela, cluster `data, grupo_input`, sem partição (≈ 1.800 linhas). Criada uma vez por `deploy/criar_…sql`; atualizada **seg–sex 09:00** pelo job `gold-agenciamento` (cresce um dia por execução). O job só exige a silver de 2026 do dia; 2024 e 2025 são carga única |
| **Arquivos** | SELECT [`sql/gld_agenciamento_entrada_diaria.sql`](../../sql/gld_agenciamento_entrada_diaria.sql) · esquema [`sql/esquemas/…csv`](../../sql/esquemas/gld_agenciamento_entrada_diaria.csv) · criação (gerada) [`deploy/criar_…sql`](../../deploy/criar_gld_agenciamento_entrada_diaria.sql) · validação [`sql/validacoes/…sql`](../../sql/validacoes/gld_agenciamento_entrada_diaria.sql) |
| **Custo** | ≈ 0,9 MB lidos por execução (dry-run de 22/10/2026; reserva Enterprise do projeto) |

## Como ler

- **Total de cards num dia** = soma de `quantidade + quantidade_estimada` de todas as linhas da data.
- **Sem os estimados** = só `quantidade`. **Sem uma família** = filtrar `familia`. **Por grupo** = filtrar `grupo_input`.
- **Saídas num dia** = soma de `quantidade_saida`. É a **1ª entrega ao cliente** (1ª ida a Aguardando Feedback), não o
  encerramento: declinados e outros fechados sem entrega não têm saída.
- Uma linha pode ter só saída (`quantidade + quantidade_estimada = 0`) ou só entrada (`quantidade_saida = 0`).
- **Série contínua** (para modelos): completar o calendário de 2024-10-01 até ontem com 0 nos dias/combinações sem
  linha — a tabela não grava zeros.

## Colunas

| # | Coluna | Tipo | Origem | Regra |
|---|---|---|---|---|
| 1 | `data` | DATE | dia da entrada (`criado_em` ou estimada pela `data_de_saida`) ou da saída dos cards contados na linha | R1–R6, R12–R15 |
| 2 | `dia_semana` | STRING | `data` (seg, ter, qua, qui, sex, sáb, dom) | R11 |
| 3 | `ano` | INT64 | `data` | R11 |
| 4 | `mes` | INT64 | `data` (1–12) | R11 |
| 5 | `inicio_semana` | DATE | segunda-feira da semana da `data` | R11 |
| 6 | `grupo_input` | STRING | `tipo_de_input` | R7 |
| 7 | `tipo_de_input` | STRING | silver, como vem; vazio = `Sem tipo` | R7 |
| 8 | `familia` | STRING | nome do projeto, marca e `tipo_de_output` | R8, R9 |
| 9 | `quantidade` | INT64 | cards com data real | R1 |
| 10 | `quantidade_estimada` | INT64 | cards com data estimada | R2 |
| 11 | `quantidade_saida` | INT64 | cards entregues ao cliente no dia | R12–R15 |
| 12 | `_processado_em` | TIMESTAMP | execução | — |

## Regras

### Data

| ID | Regra | Decidido em |
|---|---|---|
| R1 | **Data real** = `criado_em` (DATE) em 2024 e 2025; `DATE(criado_em)` em 2026. **Nunca** o `created_at` de 2024/2025: é a data da importação (03/09/2026). Conta em `quantidade` | Caio, 22/10/2026 |
| R2 | **Sem `criado_em` e com `data_de_saida`** (qualquer board) → data estimada = `data_de_saida` − **5 dias úteis** (parâmetro `dias_uteis_estimativa`). Conta em `quantidade_estimada`. **Sem as duas datas** → fora da tabela (vai ao log) | Caio, 22/10/2026 |
| R3 | **Dia útil** = seg–sex fora do calendário sem expediente da `gld_agenciamento_2026_sla_movimentos` (R14 de lá: fixos nacionais, RJ, SP e vésperas; Carnaval, Cinzas, Sexta-feira Santa e Corpus Christi pela Páscoa). O calendário está **copiado igual** no SELECT da SLA, neste SELECT e na validação desta tabela: mudar nos três juntos | Caio, 22/10/2026 |
| R4 | **Período**: de **2024-10-01 até ontem** (Brasília). Antes disso fica fora (vai ao log): jun–set/2024 tem ~12 cards em 4 meses e ensinaria um crescimento falso. Hoje não entra (dia ainda aberto) | Caio, 22/10/2026 |
| R5 | Board 2026 só `state = 'active'` | Caio, 22/10/2026 |
| R6 | **Conta pela data, não pelo board**: card do board 2024 com data de 2025 conta em 2025, e vice-versa | Caio, 22/10/2026 |

### Grupo de input

| ID | Regra | Decidido em |
|---|---|---|
| R7 | `grupo_input`: **Mercado**, **Inbound**, **Proativo** (o próprio tipo); **Internos** = ViU, Interna, Globo, ViU First, OTR (Oportunidade em Tempo Real); **Sem tipo** = `tipo_de_input` vazio. Tipo novo que apareça no board cai em **Outros** (não trava o job); quando houver, o log da execução registra um aviso **WARNING** com os valores novos de `tipo_de_input` e os cards de cada um (hoje nenhum) — decidir o grupo e incluir na lista | Caio, 22/10/2026 |

### Família

| ID | Regra | Decidido em |
|---|---|---|
| R8 | **Marca, não filtra**: todo card entra; `familia` só identifica. **Mesmo método nos três anos**, o da silver (`regras.familias_do_nome` e `eh_upfront` do PPD-SILVER-MONDAY), sobre o texto sem acento e minúsculo: **Upfront** = "upfront" no nome **ou na marca**, ignorando espaços e símbolos ("Upfront 27", "UPFRONT2027"); **Levop** `\blevop\b`, **Mídia Kit** `\b(midia\|media)[ _-]*kits?\b`, **Análise** `\b(analises?\|abalise\|aalise)\b`, **Defesa** `\bdefesas?\b`, **Curadoria** `\bcurador(ias?\|as?\|es)?\b` — no nome, palavra inteira. Pelo **tipo de output** (os 3 que a SLA exclui): `Levop \| Card de Oportunidade \| Informação por e-mail` → **Card de Oportunidade (Levop)**; `Curadoria Orçada` → **Curadoria Orçada**; `Defesas \| Estudo Comercial \| Curadorias` → **Defesas \| Estudo Comercial**. **De-para das variantes antigas** de tipo de output (boards 2024/2025), para a regra ser igual nos três anos: `Levop \| Boletim Informativo/Boletim de efeméride` → **Levop**; `Midia Kits` → **Mídia Kit**; `Defesa \| Análise \| Estudo Comercial` → **Defesas \| Estudo Comercial**. Nenhuma = **Nenhuma**. **Não** usa as colunas TRUE/FALSE da silver de 2026 (não existem em 2024 e 2025): a busca acha 199 dos 206 marcados pela silver em 2026 (Mercado/Inbound); perder 7 é melhor que misturar critérios. As outras colunas TRUE/FALSE (`exclusivo`, `vendido`, `produto_globo`, divergências, pendências) não entram | Caio, 22/10/2026 |
| R9 | **Prioridade** (card com mais de uma família fica com a primeira): **1 Upfront → 2 Levop → 3 Mídia Kit → 4 Análise → 5 Defesa → 6 Curadoria → 7 Card de Oportunidade (Levop) → 8 Curadoria Orçada → 9 Defesas \| Estudo Comercial**. Motivo: o nome do projeto é mais específico que o tipo de output (quase todas as sobreposições são o mesmo projeto pelos dois lados, ex.: "Curadoria" no nome + output "Curadoria Orçada"); Upfront é o evento que contém cotas de Levop e Curadoria ("Upfront 2027 \| Levop Cota Protagonista"); Mídia Kit antes de Análise (a Análise acompanha o Mídia Kit); Curadoria por último entre as do nome por ser a mais ampla. As variantes antigas de output (R8) entram na posição das saídas por output, depois das 6 do nome | proposta do Claude, **aprovada pelo Caio** em 22/10/2026 |
| R10 | Só as combinações com card: sem linhas com zero (quem consome completa o calendário) | Caio, 22/10/2026 |
| R11 | Colunas de calendário da `data`: `dia_semana` (abreviado em português), `ano`, `mes` e `inicio_semana` (segunda-feira; `DATE_TRUNC(data, ISOWEEK)`). Sem número de semana: a semana ISO confunde na virada do ano; para somar por semana, agrupar por `inicio_semana` | Caio, 22/10/2026 |

### Saída

| ID | Regra | Decidido em |
|---|---|---|
| R12 | **Saída = 1ª entrega ao cliente.** Board 2026: data da **1ª entrada em Aguardando Feedback** no log (`campo_alterado = 'Status'`, `valor_depois = 'Aguardando Feedback'`). Motivo: a `data_de_saida` é preenchida por automação a cada ida a Aguardando Feedback e **regravada nas reentregas** (342 cards com a data da última ida); a 1ª ida pelo log não muda depois de gravada, então um mês fechado não muda sozinho. Boards 2024 e 2025: `data_de_saida` (não há log) | Caio, 23/10/2026 (opção B) |
| R13 | Board 2026 **sem Aguardando Feedback no log** (ou só antes da criação) → `data_de_saida` (70 cards em 23/10) | Caio, 23/10/2026 |
| R14 | **Saída antes da criação não vale**: a do log antes da criação cai para a `data_de_saida`; esta também antes da criação → card **fora das saídas** (a entrada dele continua), contado no log do job. Ex.: 41 cards do board 2026 com `data_de_saida` antes da criação ficam com a data do log; 150 (2026), 16 (2025) e 1 (2024) ficam fora | Caio, 23/10/2026 |
| R15 | `quantidade_saida` com o mesmo período (R4: de 2024-10-01 até ontem; saída futura entra quando chegar), o mesmo `grupo_input` e a mesma `familia` do card (R7–R9); conta pela data, não pelo board (R6). Linha existe quando há entrada **ou** saída (R10). Fechados sem entrega (declinados) **não** entram | Caio, 23/10/2026 |

Sobreposições em 22/10/2026 (189 cards com mais de uma família): Curadoria + Curadoria Orçada 79; Defesa + Defesas \|
Estudo Comercial 37; Curadoria + Defesas \| Estudo Comercial 33; Upfront + Levop 20; Upfront + Levop + Card de
Oportunidade 8; Levop + Card de Oportunidade 5; Defesa + Card de Oportunidade 4; Curadoria + Card de Oportunidade 2;
Upfront + Curadoria + Defesas \| Estudo Comercial 1.

## Log de cada execução

As linhas "informativo" da validação vão ao log do job (Cloud Logging, mensagem "validação", severidade INFO): cards
fora por estarem antes de 2024-10-01; cards fora por não terem data (por board); cards com data estimada; total 2026
contra a referência; total por família por ano. A linha "aviso" (tipos de input novos, grupo Outros) vai como
**WARNING** quando tem valores (`job/main.py`: `esperado = 'aviso'` e resultado diferente de `0`); não bloqueia a
gravação.

## Validação

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

## Pontos de atenção

| Ponto | Efeito |
|---|---|
| Efeito do de-para das variantes antigas (R8) | só o Levop mudou: +12 cards em 2024 (Boletim Informativo; os outros 6 dos 18 são de antes de 2024-10-01 ou sem data). Os 16 "Midia Kits" de 2025 e o "Defesa \| Análise \| Estudo Comercial" de 2024 já caíam numa família pelo nome, ou ficam fora do período |
| out/2024 ainda fraco (74 cards) contra nov/2024 (129) | o Caio testa o modelo começando em out e em nov/2024 |
| Mudança de patamar 2025 → 2026 (Mercado +145% na média mensal) | tendência real ou mudança de uso do board |
| Saída em 2024 e 2025 vem da coluna (R12) | esses boards não têm log, então a B usa a `data_de_saida`. **Nesses anos, um reenvio pode ter movido a data de saída** para o dia da última ida ao cliente; não há como recuperar a 1ª. No board 2026 (com log) isso aconteceu em 437 dos 4.204 cards com saída pelo log (10%), com mediana de 8 dias (23/10/2026); a série muda de método em jan/2026 |
| Difere de relatórios feitos pela coluna | quem conta saídas pela `data_de_saida` vai achar números diferentes por causa dos reenvios: a tabela conta a 1ª entrega e a coluna guarda a última. Ex.: agosto/2026 = 561 aqui (Proativo 34) e 567 pela coluna (Proativo 54). O log do job mostra, por ano, quantos cards tiveram a `data_de_saida` regravada depois da 1ª entrega |
| Saída do board 2026 que vem da coluna (R13, 70 cards) | pode mudar se a equipe editar a `data_de_saida`; as que vêm do log ficam fixas |
| O que muda um número já gravado | card excluído no monday (sai da contagem), card que muda de tipo de input ou de nome/família (muda de linha; o total do dia fica) e recarga da silver. A 1ª ida a Aguardando Feedback em si não muda |
| Picos de saída | entregas em lote no mesmo dia (ex.: 16/10/2026, 20 Curadorias de Mercado) |
| Saída não é encerramento | declinados e standby quase nunca têm entrega; para fluxo de encerramento seria outra coluna (só 2026, pelo log) |

## Histórico

| Data | O que mudou |
|---|---|
| 22/10/2026 | Ensaios da `gld_agenciamento_demanda_diaria` (uma linha por dia, calendário contínuo; nunca criada no BigQuery) substituídos por esta tabela, por ordem do Caio: uma tabela só, grão data × grupo × tipo × família, sem zeros, famílias marcadas (não filtradas) pelo mesmo método nos três anos, estimativa para todos os boards. Validação 20/20 sem gravar |
| 22/10/2026 | **Aprovada pelo Caio** com ajustes: prioridade R9 aprovada; de-para das variantes antigas de output (R8); aviso WARNING para tipos novos (R7, `job/main.py`); referência 328 / 3.577 / 5.488; colunas de calendário `dia_semana`, `ano`, `mes`, `inicio_semana` (R11). Validação 22/22 sem gravar |
| 22/10/2026 | Revisão do Codex: validação com calendário até a maior saída (saída futura), conferência dia a dia de reais e estimados, mapa tipo → grupo; trava fixa por board histórico (327 / 3.578) no lugar da por ano (decisão do Caio); job grava as tabelas tudo ou nada. Validação toda ok sem gravar |
| 22/10/2026 | 2ª revisão do Codex (apto para implantar): calendário da validação com teto de hoje + 60 dias e só sobre cards a estimar; trava por board sem o limite "até ontem"; aviso para saída além do teto; job com ROLLBACK explícito. Validação toda ok sem gravar |
| 22/10/2026 | **Implantada** pelo Caio (Cloud Shell, a partir do commit `75bbf3c`): tabela criada e validada, permissões, job reimplantado com as duas tabelas, ensaio `rkwp9` e carga real `x4sl4` (19:08 Brasília, 1.826 linhas) |
| 23/10/2026 | **Saída** construída com o Caio (R12–R15, opção B: 1ª ida a Aguardando Feedback pelo log no board 2026; `data_de_saida` em 2024/2025 e como reserva). Coluna nova `quantidade_saida`; linhas com só saída. Ensaio sem gravar: entradas idênticas às de produção (8.842 + 592), saídas 2024: 204 · 2025: 3.012 · 2026: 4.276, recontagem dia a dia 0 diferenças, trava das saídas por board 213 / 3.005; toda validação ok. Aguarda aprovação e implantação |

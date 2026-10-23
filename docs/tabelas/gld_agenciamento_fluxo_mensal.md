# `gold_monday.gld_agenciamento_fluxo_mensal`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico.

| | |
|---|---|
| **Situação** | ✅ aprovada para implantar em 23/10/2026 (ordem do Caio); ensaio sem gravar com toda validação ok. Implantação pelo Caio: criar pelo `criar_…sql`, permissão da conta do job, incluir em `TABELAS` depois da diária |
| **Pergunta** | para os pedidos que entraram em cada mês (safra), quando cada um saiu: entregue em que mês, não seguiu em que mês, ou ainda em andamento |
| **Por que existe** | o relatório da diretoria precisa do **extrato** de cada mês: o que entrou, o que saiu do próprio mês, o que saiu de safras anteriores e o resíduo que ainda vai sair. A diária mostra o destino de cada safra (4 colunas), mas não **em que mês** cada card saiu; misturar esse grão (safra × mês do evento) na diária só confundiria |
| **O que esperamos fazer** | extrato mensal no site de relatórios (outro projeto); curva de fechamento por safra (quanto de uma safra sai em 0, 1, 2… meses) para a previsão, junto com a demanda diária da `gld_agenciamento_entrada_diaria` |
| **Saída esperada** | ≈ 620 linhas; cada card que entrou de 2024-10-01 até ontem aparece em exatamente uma combinação; total = entradas da diária; conferida em toda execução contra a diária no grão mês × grupo × tipo × família |
| **Uma linha por** | `mes_entrada` × `evento` × `mes_evento` × `grupo_input` × `tipo_de_input` × `familia`, só quando há card |
| **Quem usa** | site de relatórios (extrato da diretoria) e modelos de previsão |
| **Fontes** | as mesmas da diária: `silver_monday.slv_agenciamento_2024_itens` e `_2025_itens` (carga única), `slv_agenciamento_2026_itens` (só `state = 'active'`) e `slv_agenciamento_2026_log` (1ª ida a Aguardando Feedback e mês do status final) |
| **Materialização** | tabela, cluster `mes_entrada, evento`, sem partição. Criada uma vez por `deploy/criar_…sql`; atualizada **seg–sex 09:00** pelo job `gold-agenciamento`, **depois da diária** e na mesma transação das outras duas |
| **Arquivos** | SELECT [`sql/gld_agenciamento_fluxo_mensal.sql`](../../sql/gld_agenciamento_fluxo_mensal.sql) · esquema [`sql/esquemas/…csv`](../../sql/esquemas/gld_agenciamento_fluxo_mensal.csv) · criação (gerada) [`deploy/criar_…sql`](../../deploy/criar_gld_agenciamento_fluxo_mensal.sql) · descrições (geradas) [`deploy/descrever_…sql`](../../deploy/descrever_gld_agenciamento_fluxo_mensal.sql) · validação [`sql/validacoes/…sql`](../../sql/validacoes/gld_agenciamento_fluxo_mensal.sql) |

## 1. Como ler

- **Entradas de um mês** = soma de `quantidade` com `mes_entrada` = o mês (igual a `quantidade + quantidade_estimada`
  da diária no mês).
- **O que saiu do próprio mês** = `evento = 'entregue'` e `mes_evento = mes_entrada`. **Entregue depois** =
  `mes_evento > mes_entrada`.
- **Entregas feitas num mês** (de qualquer safra) = soma com `evento = 'entregue'` e `mes_evento` = o mês; as de safras
  anteriores são as que têm `mes_entrada < mes_evento`.
- **Resíduo** de uma safra = `evento = 'em_andamento'` (ainda vai sair). `nao_seguiu` também sai, mas sem entrega.
- **Foto do dia**: tudo é recalculado a cada execução — um card em andamento passa a entregue ou não seguiu, com o mês
  do evento. Meses fechados quase não mudam (em andamento 0 a 4 por mês em jan–set/2026).
- `nao_seguiu` com `mes_evento` NULL: o mês em que o card parou não é conhecido (boards 2024/2025 sem log, e alguns do
  2026). Para o extrato, tratar como "saiu sem data" — não somar num mês.

## 2. Pipeline (ordem do SQL) — memória de cálculo

Até o CTE `classificados`, o SQL é a cópia do da diária (mesmas regras R1–R21 de lá), com uma coluna a mais
(`status_desde`). **Mudar uma regra de card exige mudar nas duas** — a validação desta tabela confere contra a diária e
acusa qualquer diferença.

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros`, `anos`, `pascoa`, `feriados` | período (2024-10-01 até ontem), 5 dias úteis, calendário sem expediente | diária R2–R4 |
| 2 | `aguardando_feedback` | 1ª ida a Aguardando Feedback (board 2026) | diária R12 |
| 3 | `ultima_entrada_status` | última entrada de cada projeto em cada status, pelo log | F3 |
| 4 | `itens` | três boards no mesmo formato; data real com o cadastro retroativo; `status_desde` = última entrada no status atual (2026), NULL em 2024/2025 | diária R1, R5, R21; F3 |
| 5 | `cards` | data do card (real ou estimada); saída válida | diária R2, R12–R14 |
| 6 | `classificados` | situação (no mês, depois, não seguiu, em andamento), grupo e família | diária R7–R9, R16–R18 |
| 7 | `cards_evento` | um evento por card da safra; mês do evento | F1–F4 |
| 8 | SELECT final | mês do evento nunca antes do mês de entrada; conta por combinação | F4, F6 |

| Coluna | Cálculo |
|---|---|
| `mes_entrada` | `DATE_TRUNC(data do card, MONTH)`, cards com data de 2024-10-01 até ontem |
| `evento` | situação da diária: `no_mes` ou `depois` → `entregue`; `nao_seguiu`; `em_andamento` |
| `mes_evento` | entregue: `DATE_TRUNC(saída válida, MONTH)`; nao_seguiu: `DATE_TRUNC(última entrada no status atual, MONTH)` ou NULL; em_andamento: NULL; depois `GREATEST(…, mes_entrada)` |
| `quantidade` | `COUNT(*)` de cards na combinação |

Exemplo (setembro/2026, em 23/10/2026): entraram 733 cards; 460 foram entregues em setembro, 131 em outubro, 138 não
seguiram e 4 estão em andamento. Em setembro foram feitas 515 entregas: as 460 da própria safra e 55 de safras
anteriores (50 de agosto, 2 de janeiro, 2 de fevereiro, 1 de maio).

## 3. Colunas (8)

| # | Coluna | Tipo | Origem | Regra |
|---|---|---|---|---|
| 1 | `mes_entrada` | DATE | data do card (diária) | F1, F5 |
| 2 | `evento` | STRING | situação do card (diária) | F2 |
| 3 | `mes_evento` | DATE | saída válida (diária) ou log do status | F3, F4 |
| 4 | `grupo_input` | STRING | `tipo_de_input` | diária R7 |
| 5 | `tipo_de_input` | STRING | silver; vazio = `Sem tipo` | diária R7 |
| 6 | `familia` | STRING | nome, marca e `tipo_de_output` | diária R8, R9 |
| 7 | `quantidade` | INT64 | cards | F1, F6 |
| 8 | `_processado_em` | TIMESTAMP | execução | — |

## 4. Regras

Herdadas sem mudança da `gld_agenciamento_entrada_diaria`: R1–R6 e R21 (data de entrada, estimativa, período, só
ativos no 2026, conta pela data, cadastro retroativo), R7–R10 (grupo, família, prioridade, sem zeros), R12–R14 (saída =
1ª entrega, regra B) e R16–R18 (situação). Nenhuma regra nova de classificação.

| ID | Regra | Decidido em |
|---|---|---|
| F1 | **Um evento por card**: cada card com data de entrada de 2024-10-01 até ontem aparece em exatamente uma combinação; a soma de `quantidade` = entradas da diária | Caio, 23/10/2026 |
| F2 | `evento`: **entregue** = saída válida até ontem (no mês ou depois, R16 da diária); **nao_seguiu** = sem entrega e status atual Declinado (qualquer variante), Standby ou Encerrado (R17); **em_andamento** = os demais (R18) | Caio, 23/10/2026 |
| F3 | `mes_evento`: **entregue** = mês da 1ª entrega; **nao_seguiu** = mês em que o card entrou no status atual pela **última vez**, pelo log (board 2026; quem foi e voltou a Standby conta a última ida); **NULL** nos boards 2024/2025 — o `updated_at` deles é a data da importação (03/09/2026) e não há log — e no board 2026 quando o log não tem a mudança para o status atual (10 cards em 23/10/2026); **em_andamento** = NULL. Os NULL vão ao log | Caio, 23/10/2026 |
| F4 | `mes_evento` **nunca antes** de `mes_entrada`: se acontecer, usa `mes_entrada` e o caso vai ao log (aviso). 0 casos em 23/10/2026 | Caio, 23/10/2026 |
| F5 | **Período**: safras de 2024-10 em diante, até o mês de ontem. Entregas de cards que entraram antes de 2024-10-01 não aparecem (estão na `quantidade_saida` da diária: 3 em out–nov/2024) | Caio, 23/10/2026 |
| F6 | Só combinações com card (sem zeros); **foto do dia**, recalculada inteira a cada execução | Caio, 23/10/2026 |

## 5. Log de cada execução

Informativo: cards por evento e ano de entrada; `nao_seguiu` sem mês por ano de entrada e por board; saídas da diária
de cards de antes de 2024-10-01, por mês; setembro/2026 como safra e como mês de entrega, e as entregas de setembro de
safras anteriores por safra. Aviso (WARNING, não bloqueia): `nao_seguiu` com o status final antes do mês de entrada
(F4, corrigido para o mês de entrada).

## 6. Validação e números

Arquivo: [`sql/validacoes/gld_agenciamento_fluxo_mensal.sql`](../../sql/validacoes/gld_agenciamento_fluxo_mensal.sql).
Confere contra a diária, que é conferida contra uma recontagem independente nas silvers. **No job**, as duas são
calculadas na mesma sessão e a diária vem antes: o job troca o nome das duas pelas temporárias da execução
(`job/main.py`), para nunca comparar o cálculo de hoje com a carga anterior; se o fluxo vier antes da diária em
`TABELAS`, o job falha sem gravar.

Ensaio de 23/10/2026 (SELECT validado direto, contra a diária de produção da carga `nlnzw`, sem gravar): **toda ok**.

| Verificação | Resultado |
|---|---|
| chave única | 0 repetidas (622 linhas) |
| linhas inválidas, fora do período, mês do evento antes da entrada ou futuro, mês incoerente com o evento | 0 |
| total de cards = entradas da diária | 9.434 = 9.434 |
| = diária por mês × grupo × tipo × família (total, no mês, depois, não seguiu, em andamento) | 0 diferenças em 280 combinações |
| saídas por mês: entregues ≤ `quantidade_saida` da diária | ok; diferença só em out/2024 (1) e nov/2024 (2): cards que entraram antes de 2024-10-01 |
| cards por evento e ano de entrada | 2024: entregue 212 · não seguiu 105 · em andamento 11 · 2025: 3.012 · 572 · 2 · 2026: 4.388 · 972 · 160 |
| não seguiu sem mês (F3) | 2024: 105 · 2025: 572 · 2026: 10 (por board: 2026 10, 2024 e 2025 677) |
| aviso: status final antes do mês de entrada (F4) | 0 |
| set/2026 como safra | 733 = 460 no mês + 131 depois + 138 não seguiu + 4 em andamento (= referência do Caio) |
| set/2026 como mês de entrega | 515 = 460 da safra de setembro + 55 de safras anteriores (ago 50 · mai 1 · fev 2 · jan 2) |

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Mês do "não seguiu" em 2024/2025 | 677 cards sem mês (todo o não seguiu desses anos). O extrato desses meses mostra o não seguiu sem data; só o board 2026 tem o mês |
| Regras de card copiadas da diária | o SQL repete o da diária até `classificados` (inclusive o calendário de feriados, agora em 4 SQLs). Mudar nas duas juntas; a validação acusa diferença |
| Herda os limites da diária | reenvio desfazendo o cadastro retroativo (R21), saída de 2024/2025 pela coluna, card excluído ou que muda de tipo/família, foto do dia |
| Último status, não o primeiro | quem passou por Standby, voltou ao trabalho e foi encerrado conta o mês do Encerrado; quem foi a Standby duas vezes conta a segunda |

## 8. Histórico

| Data | O que mudou |
|---|---|
| 23/10/2026 | Criada por ordem do Caio (nova tabela, não colunas na diária: outro grão). Regras F1–F6; herdadas da diária. SELECT gerado a partir do da diária; validação contra a diária no grão mês × grupo × tipo × família; job passa a validar contra a versão da diária da mesma execução e a exigir a ordem. Ensaio sem gravar: toda validação ok; set/2026 733 = 460 + 131 + 138 + 4 e 515 entregas = 460 + 55 |

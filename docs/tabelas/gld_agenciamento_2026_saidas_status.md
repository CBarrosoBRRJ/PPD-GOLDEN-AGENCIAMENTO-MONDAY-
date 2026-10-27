# `gold_monday.gld_agenciamento_2026_saidas_status`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico.

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): validação 9/9 ok sobre o SELECT; criação e job pendentes |
| **Pergunta** | Dos pedidos do ano que saíram sem entrega, em que mês e com qual status (Declinado, Standby, Encerrado)? |
| **Por que existe** | O fluxo mensal conta o evento `nao_seguiu`, mas não guarda o status. O site de relatórios (página Atendimento, A26/D53) refaz essa composição lendo a silver; na gold, fica num lugar só e conferida contra o fluxo |
| **O que esperamos fazer** | Composição das saídas e exclusões A27 na página Atendimento; 3ª tabela do plano `docs/PLANO_GOLD_POR_VISUAL.md` do PPD-AGENCIAMENTO-SLA |
| **Saída esperada** | ~40 linhas (meses do ano × 3 a 5 status); soma = `nao_seguiu` da safra do ano no fluxo |
| **Uma linha por** | mês do evento × status |
| **Quem usa** | site de relatórios do Agenciamento |
| **Fontes** | `silver_monday.slv_agenciamento_2026_itens` e `slv_agenciamento_2026_log` (diárias) |
| **Materialização** | tabela (cluster `mes, status`) · atualização: job `gold-agenciamento`, seg–sex 09:00, depois da `gld_agenciamento_fluxo_mensal` |
| **Arquivos** | SELECT `sql/gld_agenciamento_2026_saidas_status.sql` · esquema `sql/esquemas/gld_agenciamento_2026_saidas_status.csv` · criação `deploy/criar_gld_agenciamento_2026_saidas_status.sql` (gerado) · validação `sql/validacoes/gld_agenciamento_2026_saidas_status.sql` |
| **Custo** | 10,5 MB por execução (dry-run de 26/10/2026; lê o log) |

## 1. Como ler

- Soma de um mês = saídas sem entrega daquele mês (safra do ano). Somar o ano dá o `nao_seguiu` do fluxo.
- Só a safra do ano: cards que entraram antes de 1º/jan não aparecem, mesmo que saiam este ano.
- `sem_data`: card sem a chegada ao status no log; vai para o mês de entrada (no fluxo, `mes_evento` NULL).

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros`, `anos`, `pascoa`, `feriados` | ontem; calendário completo para a data estimada | R3, R4 |
| 2 | `aguardando_feedback` | 1ª entrada em Aguardando Feedback (1ª entrega), pelo log | R12 |
| 3 | `ultima_entrada_status` | última entrada de cada card em cada status, pelo log | F3 |
| 4 | `itens`, `cards` | data de entrada; saída válida; status atual e desde quando | R1, R2, R5, R12–R14, R21 |
| 5 | final | safra do ano, sem saída válida até ontem e status final de não seguiu; mês do evento | R16–R19, F4, S1 |

## 3. Colunas (5)

Ver `sql/esquemas/gld_agenciamento_2026_saidas_status.csv`: mes, status, n, sem_data, _processado_em.

## 4. Regras

| ID | Regra (com o motivo) | Decidido em |
|---|---|---|
| R1–R21 (R3 completo), F3, F4 | As da `gld_agenciamento_fluxo_mensal` para o evento `nao_seguiu` | fichas da diária e do fluxo |
| S1 | Sem data no log: mês de entrada (convenção E7 do site, a mesma do quadro do Atendimento) | site, D53 |

## 5. Log de cada execução

Informativo: saídas sem entrega por mês, quantos sem data no log e os status vistos.

## 6. Validação e números

| Verificação | Resultado | Data |
|---|---|---|
| chave mês × status única | 40 linhas, 40 chaves (= auditoria do site) | 26/10/2026 |
| status válidos; contagens; meses do ano | 0; 0; 0 | 26/10/2026 |
| total = `nao_seguiu` da safra 2026 no fluxo | 974 = 974 | 26/10/2026 |
| mês a mês contra o fluxo | 0 meses diferentes | 26/10/2026 |
| por mês | jan 46 · fev 74 · mar 95 · abr 89 · mai 111 · jun 97 · jul 116 · ago 96 · set 146 · out 104 | 26/10/2026 |
| sem data no log | 10 | 26/10/2026 |
| status vistos | Declinado Internamente, Declinado pelo Mercado, Declinado pelo talento, Encerrado, Standby | 26/10/2026 |
| custo estimado (dry-run) | 10,5 MB | 26/10/2026 |

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Lê só a silver 2026 | Virada de ano: precisa da silver 2027 antes de 1º/jan |
| Regras copiadas do fluxo | Mudança de regra no fluxo precisa vir para cá; a validação mês a mês pega a divergência e para o job |
| Mês pelo status atual | Card que muda de status de saída (ex.: Standby → Declinado) troca de linha e pode trocar de mês |

## 8. Histórico

| Data | O que mudou |
|---|---|
| 26/10/2026 | Criada a partir do contrato `atendimento_status` da auditoria do site; validação 9/9 ok sobre o SELECT |
| 26/10/2026 | Calendário parcial (só feriados fixos) trocado pelo completo da diária, para a data estimada (R2) cair no mesmo mês da diária; números iguais na carga de 26/10 |

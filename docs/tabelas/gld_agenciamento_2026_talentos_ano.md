# `gold_monday.gld_agenciamento_2026_talentos_ano`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico.

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): validação 9/9 ok sobre o SELECT; criação e job pendentes |
| **Pergunta** | Quantos pedidos do ano foram de talentos exclusivos, de não exclusivos e sem talento? |
| **Por que existe** | O site de relatórios (PPD-AGENCIAMENTO-SLA, página Talentos) refaz essa conta lendo a silver (exceção D30-b de lá). Na gold, a regra fica num lugar só, validada contra a diária antes de publicar |
| **O que esperamos fazer** | Página Talentos (divisão anual e denominadores); 1ª das tabelas do plano `docs/PLANO_GOLD_POR_VISUAL.md` do site |
| **Saída esperada** | 3 linhas (uma por categoria), ano de ontem; total = entradas do ano da diária |
| **Uma linha por** | ano × categoria |
| **Quem usa** | site de relatórios do Agenciamento |
| **Fontes** | `silver_monday.slv_agenciamento_2026_itens` (diária) |
| **Materialização** | tabela (cluster `ano, categoria`) · atualização: job `gold-agenciamento`, seg–sex 09:00, depois da `gld_agenciamento_entrada_diaria` |
| **Arquivos** | SELECT `sql/gld_agenciamento_2026_talentos_ano.sql` · esquema `sql/esquemas/gld_agenciamento_2026_talentos_ano.csv` · criação `deploy/criar_gld_agenciamento_2026_talentos_ano.sql` (gerado) · validação `sql/validacoes/gld_agenciamento_2026_talentos_ano.sql` |
| **Custo** | 0,33 MB por execução (dry-run de 26/10/2026) |

## 1. Como ler

- As três categorias somam o total do ano; `pct` já fecha 100,0.
- `Não exclusivos` inclui o Squad de Talentos (`dos_quais_squad`), que é um grupo, não uma pessoa.
- Só o board 2026: a exclusividade não existe nos boards 2024/2025. Não comparar com anos anteriores.

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros` | fim = ontem (Brasília); início = 1º/jan do ano de ontem | R4 |
| 2 | `feriados` | calendário completo da diária (fixos e móveis pela Páscoa) | R3 |
| 3 | `pedidos` | data de entrada do card e exclusividade na data do pedido | R1, R2, R5, R21, T1 |
| 4 | `contagem` | conta por categoria no ano, e quantos são Squad | T2 |
| 5 | `partes` + final | percentual com 1 casa pelo maior resto | T3 |

## 3. Colunas (7)

Ver `sql/esquemas/gld_agenciamento_2026_talentos_ano.csv`: ano, categoria, n, total, pct, dos_quais_squad, _processado_em.

## 4. Regras

| ID | Regra (com o motivo) | Decidido em |
|---|---|---|
| R1, R2, R4, R5, R21 | As mesmas da `gld_agenciamento_entrada_diaria` (data de criação; sem `criado_em`, data de saída − 5 dias úteis; até ontem; só cards ativos; cadastro retroativo pela `data_de_entrada`) | ficha da diária |
| R3 | Calendário completo da `gld_agenciamento_entrada_diaria` (fixos e móveis pela Páscoa), copiado igual: serve à data estimada (R2). O contrato da auditoria usava só os fixos; trocado em 26/10/2026 porque um card sem `criado_em` com saída em 08/04/2026 caía em abril em vez de março (Sexta-feira Santa) | Claude + Caio, 26/10/2026 |
| T1 | Exclusividade = `exclusivo` da silver (na data do pedido); sem `criado_em` a silver deixa nulo e vale `talentos_exclusivos` preenchido = exclusivo | site, D30-b |
| T2 | Exclusivo nulo = Sem talento; Squad de Talentos conta em Não exclusivos | site, D31 |
| T3 | Percentual em décimos pelo maior resto, para somar 100,0 | site, D31 |

## 5. Log de cada execução

Informativo: divisão do ano (`Exclusivos: n (pct) | ...`) e total do Squad.

## 6. Validação e números

| Verificação | Resultado | Data |
|---|---|---|
| chave ano × categoria única; um ano só | 3 linhas, 3 chaves; 2026 | 26/10/2026 |
| categorias válidas; contagens sem nulo/negativo | 0 | 26/10/2026 |
| soma das categorias = entradas do ano da diária | 5.556 = 5.556 | 26/10/2026 |
| percentuais | 62,1 + 35,6 + 2,3 = 100,0 | 26/10/2026 |
| referência (= site e auditoria de 26/10) | 3.451 exclusivos + 1.980 não exclusivos + 125 sem talento; Squad 119 | 26/10/2026 |
| custo estimado (dry-run) | 0,33 MB | 26/10/2026 |

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Lê só a silver 2026 | Na virada para 2027, a tabela precisa da silver 2027 (ou de uma silver de vários anos) antes de 1º/jan; senão a validação contra a diária falha e o job para |
| Feriados copiados | Mais uma cópia do calendário da diária (pendência P1/P2 do CLAUDE.md): mudar em todas juntas |

## 8. Histórico

| Data | O que mudou |
|---|---|
| 26/10/2026 | Criada a partir do contrato `talentos_ano` da auditoria do site; validação 9/9 ok sobre o SELECT |
| 26/10/2026 | Calendário parcial (só feriados fixos) trocado pelo completo da diária, para a data estimada (R2) cair no mesmo mês da diária; números iguais na carga de 26/10 |

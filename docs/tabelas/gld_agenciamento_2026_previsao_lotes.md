# `gold_monday.gld_agenciamento_2026_previsao_lotes`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico.

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): validação 9/9 ok sobre o SELECT; igual ao site; criação e job pendentes |
| **Pergunta** | Quantos pedidos de cada dia vieram em lote (várias peças da mesma marca de uma vez) e quantos avulsos, por recorte da previsão? |
| **Por que existe** | O diagnóstico do mês em andamento da previsão (site, `ml/dados.py` S6, D56 item 3) explica o desvio do mês pelos lotes, lendo a silver; na gold, fica num lugar só e conferido contra a exclusividade diária |
| **O que esperamos fazer** | Diagnóstico de lotes da página Previsão; 7ª tabela do plano `docs/PLANO_GOLD_POR_VISUAL.md` do PPD-AGENCIAMENTO-SLA |
| **Saída esperada** | ~800 linhas no ano (dias com pedido × 4 recortes) |
| **Uma linha por** | dia × recorte (só dias com pedido no recorte) |
| **Quem usa** | site de relatórios do Agenciamento (previsão) |
| **Fontes** | `silver_monday.slv_agenciamento_2026_itens` (diária) |
| **Materialização** | tabela (cluster `data, recorte`) · atualização: job `gold-agenciamento`, seg–sex 09:00, depois da `gld_agenciamento_2026_previsao_exclusividade_diaria` |
| **Arquivos** | SELECT `sql/gld_agenciamento_2026_previsao_lotes.sql` · esquema `sql/esquemas/gld_agenciamento_2026_previsao_lotes.csv` · criação `deploy/criar_gld_agenciamento_2026_previsao_lotes.sql` (gerado) · validação `sql/validacoes/gld_agenciamento_2026_previsao_lotes.sql` |
| **Custo** | 0,56 MB por execução (dry-run de 26/10/2026) |

## 1. Como ler

- Filtrar **um** recorte. `mercado_exclusivos` e `mercado_nao_exclusivos` são partes de `mercado` (sem talento fica só em
  `mercado`); `inbound` é separado. Não somar os quatro.
- Diagnóstico do site ("até o mesmo dia"): `SUM(...) WHERE EXTRACT(DAY FROM data) <= dia de ontem`, agrupado por mês.

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros`, `anos`, `pascoa`, `feriados` | ontem; calendário completo da diária | R3, R4 |
| 2 | `pedidos` | data de entrada, tipo, marca e exclusividade de cada card ativo | R1, R2, R5, R21, T1, L1 |
| 3 | `recortes` | cada pedido no recorte do tipo e, no Mercado, no da exclusividade | L2 |
| 4 | `grupos` + final | conta por recorte × dia × marca; 3 ou mais = lote | L3 |

## 3. Colunas (7)

Ver `sql/esquemas/gld_agenciamento_2026_previsao_lotes.csv`: data, recorte, pedidos, em_lote, avulsos, lotes, _processado_em.

## 4. Regras

| ID | Regra (com o motivo) | Decidido em |
|---|---|---|
| R1–R5, R21, T1 | As da `gld_agenciamento_2026_talentos_ano` (calendário completo da diária) | ficha dela |
| L1 | Marca = coluna `marca`; sem ela, o prefixo `[Marca]` do nome do projeto | site, D56 |
| L2 | Recortes: inbound, mercado, mercado_exclusivos, mercado_nao_exclusivos (os modelos da previsão) | site, D56 |
| L3 | Lote = 3 ou mais pedidos do recorte com a mesma marca no mesmo dia; sem marca, nunca é lote | site, D56 |
| L4 | Grão diário (o site gravava 4 meses até o dia N): quem lê escolhe o período | Claude + Caio, 26/10/2026 |

## 5. Log de cada execução

Informativo: no mês de ontem, pedidos = em lote + avulsos por recorte.

## 6. Validação e números

| Verificação | Resultado | Data |
|---|---|---|
| chave data × recorte única | 781 linhas | 26/10/2026 |
| recortes, contagens, em lote + avulsos, lotes, datas | 0 erros | 26/10/2026 |
| pedidos = exclusividade diária, dia a dia e recorte a recorte | 0 diferenças | 26/10/2026 |
| igual ao site (`_sql_lotes`, 4 recortes × jun–out até o dia 25) | 20 linhas, 0 diferenças | 26/10/2026 |
| out/2026 até o dia 25 | inbound 133 = 3 + 130 · mercado 304 = 170 + 134 · exclusivos 87 = 17 + 70 · não exclusivos 185 = 118 + 67 | 26/10/2026 |
| custo estimado (dry-run) | 0,56 MB | 26/10/2026 |

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Lê só a silver 2026 | Em janeiro, o diagnóstico "4 meses anteriores" não tem os meses de 2025; precisa da silver de vários anos |
| Lote é aproximação | Mesma marca no mesmo dia pode ser coincidência; não prova a causa do desvio (auditoria do site) |

## 8. Histórico

| Data | O que mudou |
|---|---|
| 26/10/2026 | Criada a partir do contrato `previsao_lotes` da auditoria do site, em grão diário e com calendário completo; validação 9/9 e igual ao site |

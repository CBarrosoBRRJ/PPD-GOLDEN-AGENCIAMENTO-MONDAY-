# `gold_monday.gld_agenciamento_2026_talentos_ranking`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico.

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): validação 12/12 ok sobre o SELECT; criação e job pendentes |
| **Pergunta** | Quais talentos concentram os pedidos do ano, em cada recorte, e como chegaram lá mês a mês? |
| **Por que existe** | O site de relatórios (página Talentos: top 10, mapa mensal e corrida do ano) refaz o ranking lendo a silver (exceção D30-b de lá). Na gold, a regra fica num lugar só, conferida contra a `gld_agenciamento_2026_talentos_ano` |
| **O que esperamos fazer** | Página Talentos do site; 2ª tabela do plano `docs/PLANO_GOLD_POR_VISUAL.md` do PPD-AGENCIAMENTO-SLA |
| **Saída esperada** | ~430 linhas; 3 recortes; 10 talentos nos lugares 1–10 de cada recorte e mais os que só passaram pela corrida |
| **Uma linha por** | grupo × talento × mês com pedido |
| **Quem usa** | site de relatórios do Agenciamento |
| **Fontes** | `silver_monday.slv_agenciamento_2026_itens` (diária) |
| **Materialização** | tabela (cluster `grupo, pos`) · atualização: job `gold-agenciamento`, seg–sex 09:00, depois da `gld_agenciamento_2026_talentos_ano` |
| **Arquivos** | SELECT `sql/gld_agenciamento_2026_talentos_ranking.sql` · esquema `sql/esquemas/gld_agenciamento_2026_talentos_ranking.csv` · criação `deploy/criar_gld_agenciamento_2026_talentos_ranking.sql` (gerado) · validação `sql/validacoes/gld_agenciamento_2026_talentos_ranking.sql` |
| **Custo** | 0,33 MB por execução (dry-run de 26/10/2026) |

## 1. Como ler

- Filtrar **um** `grupo`. `todos` soma exclusivo + não exclusivo pelo nome; não somar os três recortes.
- `n`, `pos`, `ultimo_pedido`, `empate_fora` e `talentos_grupo` repetem em todas as linhas do talento (ou do recorte):
  para o top 10, `SELECT DISTINCT grupo, talento, n, pos ... WHERE pos <= 10`.
- `pos > 10`: talento que esteve entre os 10 do acumulado no fim de algum mês, mas não fechou o ano entre os 10.

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros`, `feriados`, `pedidos` | iguais à `gld_agenciamento_2026_talentos_ano` | R1, R2, R3, R4, R5, R21, T1 |
| 2 | `validos` | pedidos do ano com talento nomeado, em seu recorte e em `todos`; nome normalizado como chave | K1, K2 |
| 3 | `grafias`, `ranking` | soma por chave; grafia mais frequente | K1 |
| 4 | `ranqueado`, `fora` | lugar no ano (empate alfabético); empatados com o 10º fora da lista | K3 |
| 5 | `por_mes`, `acumulado`, `na_corrida` | pedidos por mês; quem esteve entre os 10 do acumulado em algum mês | K4 |

## 3. Colunas (10)

Ver `sql/esquemas/gld_agenciamento_2026_talentos_ranking.csv`.

## 4. Regras

| ID | Regra (com o motivo) | Decidido em |
|---|---|---|
| R1–R5, R21, T1 | As da `gld_agenciamento_2026_talentos_ano` | ficha dela |
| K1 | Nomes agrupados sem diferença de maiúsculas e espaços, mostrados na grafia mais frequente (grafias soltas, PD02b do site) | site, 24/10/2026 |
| K2 | Fora do ranking: Squad de Talentos (é um grupo) e pedido sem talento | site, D50 |
| K3 | Empate no ano pela ordem alfabética; `empate_fora` conta quem ficou fora com os pedidos do 10º | site, decisão 11, 25/10/2026 |
| K4 | Corrida do ano: entram também os 10 do acumulado no fim de cada mês, com desempate pelo lugar no ano | site, D51, 26/10/2026 |

## 5. Log de cada execução

Informativo: 1º lugar de cada recorte e quantos talentos estão só na corrida (`pos > 10`).

## 6. Validação e números

| Verificação | Resultado | Data |
|---|---|---|
| chave grupo × talento × mês única | 431 linhas, 431 chaves (= auditoria do site) | 26/10/2026 |
| recortes, talentos válidos, contagens, meses do ano | 3; 0; 0; 0 | 26/10/2026 |
| n = soma dos meses; top 10 completo nos 3 recortes | 0 divergências | 26/10/2026 |
| top 10 ≤ categoria da talentos_ano | exclusivo 1.808 de 3.451 · nao-exclusivo 225 de 1.980 · todos 1.808 de 5.431 | 26/10/2026 |
| 1º lugar | Tatiana Machado (282) em exclusivo e todos; Jonas Fernando Sulzbach (65) em nao-exclusivo | 26/10/2026 |
| só na corrida | exclusivo 7 · nao-exclusivo 11 · todos 7 | 26/10/2026 |
| custo estimado (dry-run) | 0,33 MB | 26/10/2026 |

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Lê só a silver 2026 | Mesma virada de ano da `gld_agenciamento_2026_talentos_ano` |
| Grafia mais frequente | Se a grafia dominante de um talento mudar, o nome exibido muda; a contagem não |

## 8. Histórico

| Data | O que mudou |
|---|---|
| 26/10/2026 | Criada a partir do contrato `talentos_ranking` da auditoria do site; validação 12/12 ok sobre o SELECT |
| 26/10/2026 | Calendário parcial (só feriados fixos) trocado pelo completo da diária, para a data estimada (R2) cair no mesmo mês da diária; números iguais na carga de 26/10 |

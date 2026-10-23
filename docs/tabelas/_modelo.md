# `gold_monday.gld_agenciamento_<tema>`

<!-- Copiar para docs/tabelas/<tabela>.md. É o PRD da tabela: tudo o que foi decidido, feito e medido fica aqui, com
     data. Arquivos da tabela: sql/<tabela>.sql, sql/esquemas/<tabela>.csv, sql/validacoes/<tabela>.sql;
     deploy/criar_<tabela>.sql é gerado por tools/gerar_deploy.py. -->

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico.

| | |
|---|---|
| **Situação** | 📝 em definição · 🧪 SQL em validação · ✅ aprovada · 🚀 em produção (desde …) |
| **Pergunta** | o que a tabela responde, em uma frase |
| **Por que existe** | o problema de quem pede (o que não dá para ver no monday ou no relatório de hoje) |
| **O que esperamos fazer** | relatórios, modelos, decisões que vão usar a tabela |
| **Saída esperada** | grão, ordem de grandeza (linhas), período e o que é conferido em toda execução |
| **Uma linha por** | |
| **Quem usa** | |
| **Fontes** | silvers lidas (e quais são diárias ou carga única) |
| **Materialização** | tabela (cluster, partição) · atualização: job `gold-agenciamento`, seg–sex 09:00 |
| **Arquivos** | SELECT `sql/<tabela>.sql` · esquema `sql/esquemas/<tabela>.csv` · criação `deploy/criar_<tabela>.sql` (gerado) · validação `sql/validacoes/<tabela>.sql` |
| **Custo** | MB lidos por execução (dry-run de …) |

## 1. Como ler

- Como somar, filtrar e o que **não** misturar.

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros` | | |

Como cada número nasce:

| Coluna | Cálculo |
|---|---|
| | |

Exemplo com um card/projeto real: entrada → cálculo → o que sai em cada coluna.

## 3. Colunas (N)

| # | Coluna | Tipo | Origem (tabela.coluna) | Regra |
|---|---|---|---|---|
| 1 | | | | |

## 4. Regras

| ID | Regra (com o motivo) | Decidido em |
|---|---|---|
| R1 | | Caio, dd/mm/aaaa |

## 5. Log de cada execução

O que a validação manda ao log do job como informativo e o que vira aviso (WARNING, não bloqueia).

## 6. Validação e números

| Verificação | Resultado | Data |
|---|---|---|
| grão único | | |
| contagem × silver (recontagem independente, dia a dia) | | |
| nulos e negativos nas colunas-chave | | |
| custo estimado (dry-run) | | |

Números de referência de cada ensaio, com data e de onde vieram.

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| | |

## 8. Histórico

| Data | O que mudou |
|---|---|
| | |

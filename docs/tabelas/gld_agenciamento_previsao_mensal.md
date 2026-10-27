# `gold_monday.gld_agenciamento_previsao_mensal` (view)

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): igual ao site; criação pendente |
| **Pergunta** | Quantos pedidos de Inbound e de Mercado entraram em cada mês desde 2024-10? |
| **Por que existe** | A previsão do site (`ml/dados.py`, `SQL_SERIE`, séries S1 e S2) soma a diária por mês |
| **Uma linha por** | mês × tipo (Inbound, Mercado) |
| **Base** | `gld_agenciamento_entrada_diaria` (soma por mês, sem regra própria). View, não entra no job |

## Validação (26/10/2026)

50 linhas (25 meses × 2 tipos) iguais à `SQL_SERIE` do site, inclusive `completo` e `dados_ate`.

## Validação no projeto (`sql/validacoes/gld_agenciamento_previsao_mensal.sql`, 27/10/2026)

Sem gravar, sobre o SQL da view: 8/8 ok. 50 linhas = 25 meses × 2 tipos; total 7.242 = entradas Inbound + Mercado da diária até ontem; só o mês de ontem parcial; em 2026, mês × tipo = `gld_agenciamento_2026_previsao_exclusividade_diaria` (no ensaio, pela diária, que é igual a ela dia a dia). Out/2026: Inbound 139, Mercado 335.

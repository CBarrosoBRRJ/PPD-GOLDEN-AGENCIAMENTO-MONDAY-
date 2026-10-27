# `gold_monday.gld_agenciamento_fila_mensal` (view)

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): igual ao site; criação pendente |
| **Pergunta** | Em cada mês, quanto estava na fila no início, quanto entrou, quanto saiu (entregue ou sem entrega) e quanto ficou, por mês de entrada? |
| **Por que existe** | O extrato do Início do site (`entrada/calculos.py:extrato()`, E7) reconstrói a fila sobre o fluxo mensal |
| **Uma linha por** | mês × mês de entrada (só com algum número) |
| **Base** | `gld_agenciamento_fluxo_mensal`. View, não entra no job |

## Regras

| ID | Regra |
|---|---|
| FM1 | A fila só conta pedidos do próprio ano do mês (Caio, 23/10/2026); de safras de anos anteriores, só as entregas do mês (`do_ano = FALSE`) |
| FM2 | "Não seguiu" sem data conta no mês de entrada e não fica represado |
| FM3 | Represados = safras anteriores do ano em andamento ou com evento no mês ou depois; seguem = em andamento ou com evento depois do mês |

Leitura do extrato de um mês: represados = `SUM(represados)`; novos = `SUM(novos)`; entregues dos novos = `entregues` da
linha `mes_entrada = mes`; dos represados = das demais com `do_ano`; anos anteriores = `entregues` com `do_ano = FALSE`.

## Validação (26/10/2026, contra `extrato()` do site, gold de produção)

25 meses (2024-10 a 2026-10): represados, novos, entregues dos novos e dos represados, não seguiram, seguem, entregas de
anos anteriores e as dicas por mês de entrada — 0 diferenças.

## Validação no projeto (`sql/validacoes/gld_agenciamento_fila_mensal.sql`, 27/10/2026)

Sem gravar, sobre o SQL da view: 10/10 ok. 120 linhas, 25 meses (2024-10 a 2026-10) sem buraco; em toda safra do ano novos + represados − entregues − não seguiram = seguem; o que segue num mês = represado no seguinte; safras de anos anteriores só com entregas (FM1); entregas = 7.677 = entregue do fluxo mensal. Out/2026: 586 | 173 | 484 | 111 | 164.

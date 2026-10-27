# `gold_monday.gld_agenciamento_atendimento_mensal` (view)

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): igual ao site; criação pendente (depois da `gld_agenciamento_2026_saidas_status`) |
| **Pergunta** | A equipe deu conta do que havia para atender no mês? |
| **Por que existe** | A página Atendimento do site (`atendimento/calculos.py`: `atendimento()`, `status_sem_entrega()`, `analise_ritmo()`) reconstrói a fila e o denominador A27 |
| **Uma linha por** | mês (2025-01 até o mês de ontem) |
| **Bases** | `gld_agenciamento_entrada_diaria`, `gld_agenciamento_fluxo_mensal`, `gld_agenciamento_2026_saidas_status`. View, não entra no job |

## Regras

| ID | Regra |
|---|---|
| AM1 | Só pedidos do próprio ano; a fila recomeça em janeiro (D29 do site) |
| AM2 | Saída sem entrega sem data = mês de entrada (E7 do site) |
| AM3 | Externos = Declinado pelo Mercado, Declinado pelo talento, Encerrado; só no mês em que a composição por status soma igual ao sem entrega (A26/A27); senão 0 |

% de entrega (A27) = `entregues ÷ dependia`, calculado por quem lê.

## Validação (26/10/2026, contra o site, gold de produção)

10 meses de 2026: entradas, entregues, sem entrega, ficou, veio, para atender, externos e dependia — 0 diferenças.
Ano: externos 160, dependia 5.396 (iguais). Out/2026: 717 para atender − 19 externos = 698; 446 ÷ 698 = 64%.

## Validação no projeto (`sql/validacoes/gld_agenciamento_atendimento_mensal.sql`, 27/10/2026)

Sem gravar, sobre o SQL da view (com a `gld_agenciamento_2026_saidas_status` pelo SELECT dela): 11/11 ok. 22 meses (2025-01 a 2026-10) sem buraco; contas do mês fecham; janeiro sem fila do ano anterior (AM1); externos só com a composição conferida (AM3), conferida em todos os meses de 2026; o que ficou = seguem da `gld_agenciamento_fila_mensal` em 2026. Out/2026: entradas 586, entregues 484, sem entrega 111, ficou 164, externos 20.

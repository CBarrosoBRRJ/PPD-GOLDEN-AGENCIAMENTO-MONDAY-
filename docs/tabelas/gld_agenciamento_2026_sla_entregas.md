# `gold_monday.gld_agenciamento_2026_sla_entregas` e `gld_agenciamento_2026_sla_entregas_status` (views)

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): iguais ao site; criação pendente (depois da coluna R24 na SLA) |
| **Pergunta** | Quanto tempo de trabalho da equipe (sem almoço) cada orçamento levou até a 1ª entrega, e em que status? |
| **Por que existe** | A página SLA e o estudo "Como medimos" do site (PPD-AGENCIAMENTO-SLA) recalculam o expediente sem almoço e agregam por 1ª entrega em `sla/calculos.py:entregas()`; com a R24 na gold, isso vira uma view |
| **Uma linha por** | `sla_entregas`: orçamento entregue · `sla_entregas_status`: orçamento × status |
| **Base** | `gld_agenciamento_2026_sla_movimentos` (coluna `sla_sem_almoco_horas`, R24). View: sempre igual à base, não entra no job |
| **Arquivos** | `sql/<view>.sql`, `sql/esquemas/<view>.csv`, `deploy/criar_<view>.sql` (gerado) |

## Regras (as do site, IDs de lá entre parênteses)

| ID | Regra |
|---|---|
| E1 (C4) | 1ª entrega = 1º passo com fase cliente; se for o passo 1, não é entrega (fica fora) |
| E2 (C2, C9, C14) | Trabalho = passos da fase equipe antes da 1ª entrega, sem "Em elaboração - Retorno Marca"; fila = status Entrada; elaboração/revisão pelo começo do nome |
| E3 (C3) | Calendário = horas corridas do pedido à 1ª entrega |
| E4 (C3c) | Dias úteis com fração = todas as horas sem almoço até a entrega ÷ 8 |
| E5 (C3b) | Dias úteis inteiros: pedido depois das 19h ou fora de dia útil conta do próximo dia útil; calendário da R14 copiado |
| E6 (C10, J1, X6) | Exclusividade e tipo do passo 1; pacote = nome começa por `[Pacote` |

## Validação (26/10/2026, contra `entregas()` e `horas_por_status()` do site, sobre o mesmo cálculo da SLA)

| Verificação | Resultado |
|---|---|
| orçamentos | 2.614 = 2.614, nenhum só de um lado |
| h_trabalho, h_fila, h_elaboracao, h_revisao, dias_uteis_fr | diferença máxima 6e-14 h |
| dias_uteis, mês, exclusivo, tipo, pacote | 0 diferenças |
| faixas ≤ 8 h, ≤ 16 h, ≤ 40 h | 0 orçamentos mudam de faixa; mediana idêntica (14,308 h com out/2026) |
| horas por status | 6.878 = 6.878 linhas, diferença máxima 1e-14 h |

Com a R24 arredondada a 4 casas, 1 orçamento mudava de faixa em 8 h e em 16 h: por isso a R24 ficou sem arredondar.

## Validação no projeto (`sql/validacoes/`, 27/10/2026)

`gld_agenciamento_2026_sla_entregas.sql` e `gld_agenciamento_2026_sla_entregas_status.sql`, rodadas sem gravar sobre o SQL das views, com `sla_util_horas` no lugar da coluna R24 (ainda não está em produção): todas ok. 2.655 entregas, chave única e população = projetos da SLA com o 1º passo com o cliente depois do passo 1; 0 datas, meses ou horas inválidos; fila + elaboração + revisão nunca acima do trabalho. Por status: 7.021 linhas, nenhum Retorno Marca, soma por orçamento = `h_trabalho` em todos. Aviso previsto: horas zero até a 1ª execução do job com a R24.

## Histórico

| Data | O que mudou |
|---|---|
| 26/10/2026 | Criadas para tirar do site o recálculo do expediente (PD21 de lá) |

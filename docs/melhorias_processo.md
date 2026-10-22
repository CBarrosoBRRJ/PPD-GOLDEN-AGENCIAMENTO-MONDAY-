# Melhorias de processo e de dados — SLA do Agenciamento

Levantado na construção da `gld_agenciamento_2026_sla_movimentos` (21/10/2026). Nada aqui trava a tabela atual: são
definições e hábitos que deixam o SLA mais confiável. Cada item diz o que pedir, por que e o que muda na gold quando
resolvido.

## 1. Definições a fechar com a equipe

| # | Definir | Por que | Quando resolvido |
|---|---|---|---|
| L1 | **Meta de SLA** por tipo de projeto (input, output, prioridade) e o limite do alerta de cliente sem retorno (hoje 10 dias úteis, provisório) | hoje a tabela mede o tempo, mas não diz se o prazo foi cumprido | coluna "dentro da meta" por passo/fase; parâmetro do alerta ajustado |
| L2 | **Dono de cada status**: equipe, talento, Talent Manager, marca ou área externa (GP, Audiência, Cotação Externa, Gestão de Elenco, Gestão Esporte, Retorno Marca/Executivo) | separar o tempo da equipe do tempo de quem ela espera | dicionário status → responsável; nova coluna de responsável por passo |
| L6 | **Expediente e ausências**: o horário 10h–19h vale para todos? Férias e folgas | o tempo útil assume a mesma jornada para todos | calendário por pessoa, se fizer sentido |

## 2. Hábitos de preenchimento no monday

| # | Pedido | O que vimos (21/10/2026) |
|---|---|---|
| H1 | **Toda entrega passa por Aguardando Feedback**, inclusive a de um retrabalho, antes de encerrar | 21 projetos voltaram para ajuste e foram encerrados sem registrar a nova entrega (ex.: [Zoop] Zeca Camargo) |
| H2 | **Desistência é Declinado, não Encerrado** | 33 projetos foram encerrados sem nunca ir ao cliente; 8 saíram direto da Entrada para Encerrado |
| H3 | **Mudar o Status na hora** em que a etapa muda (L5) | o tempo medido é o do card; atraso no registro infla a etapa anterior |
| H4 | **Conferir antes de clicar** no Status | 154 idas e voltas em menos de 2 minutos (cliques corrigidos), 95 delas em Aguardando Feedback — a gold já ignora, mas poluem o histórico |
| H5 | **Reabrir com motivo**: projeto encerrado ou declinado que volta a andar | 75 reaberturas, quase metade de Encerrado e o resto de Declinado |
| H6 | **Status preenchido desde a criação** (o projeto nasce em Entrada) | no board antigo, 692 projetos nasceram sem status e 578 já num status do meio — ficaram fora do SLA |

## 3. Colunas novas a pedir no board

| # | Coluna | Tipo | Para quê |
|---|---|---|---|
| L9 | **Motivo da volta** (retrabalho, reabertura, fechamento sem Aguardando Feedback) | lista: pedido de ajuste da marca, mudança de escopo, erro interno, novo talento, outro | explicar retrabalhos e reaberturas; entra pela silver e pelo log, com o valor da época, na própria tabela de SLA |

## 4. O que dá para fazer nos dados, sem a equipe

| # | Item | Como |
|---|---|---|
| L4 | Responsável do Orçamento **na época** de cada passo | reconstruir pelo log (mudanças da coluna Orçamento) |
| L7 | Complexidade e urgência: prazo da marca (`deadline`), valor, nº de talentos, "URGENTE" no nome | já existe na silver itens; escolher as colunas |
| L8 | Carga da equipe (projetos abertos ao mesmo tempo) | calcular pelo próprio histórico de status |

## 5. Novas medidas a criar na gold (pedido do Caio, 21/10/2026)

Levantadas no site de relatórios (`../PPD-AGENCIAMENTO-SLA`, slide "Quanto tempo levamos para entregar um orçamento?").

| # | Medida | Por que | Efeito medido (21/10/2026, jan–set, 2.428 entregues) | O que muda na gold |
|---|---|---|---|---|
| L10 | **Espera na fila (backlog)**: o tempo em **Entrada** vira uma medida própria — mas **continua dentro do tempo da equipe** (decisão do Caio, 21/10/2026: a fila está sob controle da equipe) | separar quanto do tempo da equipe é fila e quanto é trabalho; o cliente já está esperando desde a Entrada | Entrada é **24% das horas** de trabalho até a 1ª entrega; mediana com Entrada 17,2 h úteis, sem Entrada **9,8 h**; prontos em até 18 h: 53% → **68%** | nova fase (ex.: `fila`) ou coluna separando Entrada de `equipe`; o tempo do cliente (corrido) continua contando desde a Entrada |
| L11 | **Retrabalho medido à parte**: o tempo da equipe depois que o cliente devolve (volta de Aguardando Feedback) conta, mas como **retrabalho**, separado do tempo da 1ª entrega | a 1ª entrega mede a resposta ao pedido; o retrabalho mede ajustes — misturar esconde os dois | hoje a 1ª entrega já ignora o que vem depois; o retrabalho está marcado por passo (`retrabalho`, R19), sem total de horas | coluna de ciclo (1ª entrega, retrabalho 1, 2…) ou total de horas de retrabalho por projeto |

## 6. Uso no dia a dia (Power BI)

- **Cobrança da marca:** filtrar `alerta = TRUE` (cliente sem retorno há mais de 10 dias úteis), com o link do projeto.
- **Horas extras:** `fora_expediente` e `hora_extra_horas` por `saida_por` e por mês.
- **Retrabalho e reaberturas:** `retrabalho`, `reaberto`, `entrega_sem_aguardando`, `encerrado_sem_entrega`.

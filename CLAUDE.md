# PPD-GOLDEN-AGENCIAMENTO-MONDAY — guia para retomar

Leia este arquivo primeiro. Ele diz o que é o projeto, o que está em produção, o que está pendente e como trabalhar
aqui. Os detalhes estão nos documentos indicados; não releia tudo se a tarefa não pedir.

## O que é

Pipeline da camada **gold** do board **Backlog 2026 | Agenciamento** (monday.com), a partir das silvers do projeto
irmão `../PPD-SILVER-MONDAY`. Consumidor: **Power BI** (e, no futuro, um site de relatórios, em outro projeto).
Responsável: Caio Barroso (conta corporativa `caio.barroso@viu.com.br`, projeto GCP `gglobo-viu-dados-hdg-prd`).
Nota no Obsidian: `G:/Meu Drive/SecondBrain/B Trabalho/VIU Agenciamento/Projetos/B016 Gold Monday - Agenciamento 2026.md`.

```text
bronze 08:00 (PPD-BRONZE-MONDAY) → silver 08:30 (PPD-SILVER-MONDAY) → gold 09:00 (este projeto) → Power BI
```

## Estado (21/10/2026)

| Item | Estado |
|---|---|
| `gold_monday.gld_agenciamento_2026_sla_movimentos` | 🚀 **em produção** desde 21/10/2026 — uma linha por passagem de um projeto por um status; 36 colunas; regras R1–R23; 14.838 linhas / 3.105 projetos em 22/10; validação 19/19. **Concluída** |
| `gold_monday.gld_agenciamento_entrada_diaria` | 🚀 **em produção** desde 22/10/2026 — cards criados por data × grupo de input × tipo × família (boards 2024–2026), data estimada separada; 1.826 linhas na 1ª carga; validação toda ok. **Saída** (`quantidade_saida`, R12–R15, D18: 1ª entrega ao cliente) em produção desde 23/10/2026 — 2.333 linhas, 7.492 saídas na carga de 23/10. **Situação por safra** (`entregue_no_mes`, `entregue_depois`, `nao_seguiu`, `em_andamento`; R16–R20, D19; foto do dia) em produção desde 23/10/2026 — 16 colunas; carga `ksw7n`: 2.333 linhas, agosto/2026 640 = 486 + 50 + 101 + 3. **Cadastro retroativo** (R21, D20: card do board 2026 com `data_de_saida` antes da criação e `data_de_entrada` até ela entra pela `data_de_entrada`) pedido pelo Caio em 23/10/2026 — em produção desde 23/10/2026 (carga `nlnzw`: 2.336 linhas; 154 cards corrigidos; outubro 600 → 508, não seguiu 164 → 74); sem coluna nova. **Concluída** |
| `gold_monday.gld_agenciamento_fluxo_mensal` | ✅ **aprovada** em 23/10/2026 — extrato por safra: mês de entrada × evento (entregue, nao_seguiu, em_andamento) × mês do evento × grupo × tipo × família; regras F1–F6 e as de card da diária (SELECT copiado até `classificados`); ensaio sem gravar ok (622 linhas; set/2026 733 = 460 + 131 + 138 + 4). **Implantação com o Caio** (criar, permissão, `TABELAS` depois da diária) |
| Job `gold-agenciamento` | Cloud Run Job (`us-central1`) + Scheduler `gold-agenciamento-diario` **seg–sex 09:00** (Brasília); atualiza as duas tabelas **tudo ou nada** (D16); código do commit `da661ef` (23/10/2026) |
| Alerta | política "gold-agenciamento falhou" → e-mail (testado em 21/10) |
| Git / GitHub | repositório privado `https://github.com/CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-` (criado em 22/10/2026, branch `main`). Deploy por `git clone` no Cloud Shell; o `.env` fica fora. Commit e push só quando o Caio pedir |

Detalhe da produção (conta de serviço, permissões, execuções, ids): `deploy/gcp_setup.md`, seção "Estado da produção".

## Pendências

| # | Pendência | Quem |
|---|---|---|
| 1 | ✅ 1ª execução automática conferida: 22/10/2026 09:02 (Brasília), SLA gravada | — |
| 2 | Conferir a 1ª execução automática com a saída (seg 26/10/2026 09:00): `_processado_em` das duas ≈ 26/10 12:0x UTC — **não** iguais entre si: cada uma marca o horário do próprio cálculo (segundos de diferença); a gravação é que é numa transação só; `quantidade_saida` e as 4 colunas de situação por safra preenchidas; linha `cadastro retroativo` do log com 2025: 9 · 2026: 145 (ou perto); nenhuma linha ERROR/WARNING no log. Depois: **próximas tabelas gold** (o Caio traz os temas). Lembrete: o calendário de feriados está copiado igual na SLA, na entrada diária e na validação dela — mudar nos três juntos | Claude (leitura) a pedido; Caio + Claude |
| 3 | ✅ Repositório no GitHub criado e deploy trocado por `git clone` (22/10/2026) | — |
| 4 | Relatório/dash/site de SLA lendo a tabela — **em outro projeto** | Caio |
| 5 | Levar à equipe `docs/melhorias_processo.md` (meta de SLA, dono de cada status, hábitos no monday, coluna "Motivo da volta") | Caio |
| 6 | Quando a equipe definir a meta (L1): ajustar `alerta_dias_uteis_cliente` (hoje 10, provisório) no SELECT | Claude + deploy |
| 7 | Variação `gld_agenciamento_2026_sla_projetos` (totais por projeto) — rascunho em `sql/rascunhos/`, não aprovada | a decidir |
| 8 | Candidatas sem depender da equipe: responsável na época de cada passo (L4), complexidade/urgência (L7), carga da equipe (L8) | a decidir |
| 9 | Revisão do Codex (22/10/2026), ainda abertas: **A7** — o job autorizar pela marca de lote concluído da silver (labels `lote_*` da foto diária), não só pela data; **SLA** — reconciliar o número de projetos com o recorte (hoje só "> 0"); **P1/P2** — testes sintéticos das regras e do job, identificador da execução, calendário de feriados numa definição só (hoje copiado em 4 SQLs: SLA, diária, validação da diária e fluxo mensal — o fluxo copia também as regras de card da diária), cadastro único das tabelas, alerta de carga que não aconteceu; o `validacao.replace(destino, novo)` do job troca texto, não SQL (um comentário ou literal com o nome completo da tabela também seria trocado — hoje só há a ocorrência do `FROM`); `TABELAS` diferente da produção só avisa (D16), não impede. Auditoria do Codex de 23/10/2026 (R21): a validação da entrada diária reconcilia por **dia**, não pelo grão completo (grupo, tipo, família) — uma troca sistemática de rótulos passaria; a R21 lê a `data_de_saida` atual, então uma **reentrega** de card corrigido o devolve ao mês do cadastro (decisão do Caio pendente) | a decidir |

## Onde está cada coisa

| Para | Leia |
|---|---|
| visão geral, convenções, decisões D1–D20, próximos passos, histórico | `docs/PRD.md` |
| a tabela SLA: como ler, pipeline, 36 colunas, regras R1–R23, números, validação, limitações | `docs/tabelas/gld_agenciamento_2026_sla_movimentos.md` |
| o fluxo mensal (extrato por safra): PRD da tabela, regras F1–F6, validação contra a diária | `docs/tabelas/gld_agenciamento_fluxo_mensal.md` |
| a entrada diária: PRD da tabela (pergunta, por quê, memória de cálculo, 16 colunas, regras R1–R21, números de cada ensaio, validação, pontos de atenção) | `docs/tabelas/gld_agenciamento_entrada_diaria.md` |
| colunas das silvers de origem | `docs/fontes.md` |
| o que pedir à equipe e melhorar no processo e nos dados (L1–L9, H1–H6) | `docs/melhorias_processo.md` |
| implantar, atualizar, incluir tabela, operar, estado da produção | `deploy/gcp_setup.md` |
| estrutura de pastas e como criar/atualizar uma tabela | `README.md` |

## Como trabalhar aqui

1. **Uma tabela por vez, com o Caio:** tema e grão → colunas (mostrar as da silver) → regras (cada uma com ID na ficha,
   decisão com data) → SQL → validação → aprovação → criação → job. Mostrar exemplos na tela com **todas as colunas em
   cada linha** e o link no final; validar com projetos reais (com link) antes de aprovar.
2. **Arquivos de cada tabela** (o nome do arquivo é o nome da tabela): `sql/<tabela>.sql` (SELECT, fonte da verdade),
   `sql/esquemas/<tabela>.csv` (colunas, tipos, descrições), `sql/validacoes/<tabela>.sql` (toda linha `ok = TRUE`),
   `docs/tabelas/<tabela>.md` (ficha = **PRD da tabela**: pergunta, por quê, saída esperada, memória de cálculo, regras com ID e data, validação com números, histórico; a partir de `_modelo.md`). `deploy/criar_<tabela>.sql` é **gerado** por
   `python tools/gerar_deploy.py` — não editar à mão.
3. **Levar ao GCP:** commit e push (quando o Caio pedir) → `git clone` no Cloud Shell → comandos de
   `deploy/gcp_setup.md`. Tabela nova: criar pelo `deploy/criar_…sql`, dar `dataEditor` à conta `gold-agenciamento`
   na tabela (e `dataViewer` em fonte nova), incluir em `TABELAS` e reimplantar.
4. **GCP corporativo: só consultas.** O Claude lê metadados, amostras e faz dry-run (MCP BigQuery). Criar/alterar
   tabelas, permissões, job, agendamento e alerta é com o Caio: entregar o comando pronto, um bloco por vez, e
   aguardar a saída.
5. **Regras de negócio não mudam sem o Caio.** Não recalcular o que a silver já resolve; mudança de regra da silver é
   no `PPD-SILVER-MONDAY`. Nada é gravado no monday.
6. Atualizar a ficha, o PRD (decisões e histórico) e, se mudar a produção, `deploy/gcp_setup.md` e a nota B016.

## Prompt para retomar

```text
Leia o CLAUDE.md de G:/Meu Drive/Workspace/globo/scripts/PPD-GOLDEN-AGENCIAMENTO-MONDAY e a nota do Obsidian B016
(B Trabalho/VIU Agenciamento/Projetos/B016 Gold Monday - Agenciamento 2026.md). Confira, só com leitura no BigQuery,
se o job gold-agenciamento rodou hoje (_processado_em e a validação). Depois vamos criar novas tabelas gold:
[descreva o tema].
```

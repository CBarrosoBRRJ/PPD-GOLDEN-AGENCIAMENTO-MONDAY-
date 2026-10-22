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
| `gold_monday.gld_agenciamento_entrada_diaria` | 🚀 **em produção** desde 22/10/2026 — cards criados por data × grupo de input × tipo × família (boards 2024–2026), data estimada separada; 1.826 linhas na 1ª carga; validação toda ok. **Concluída** (para previsão de demanda; análises ficam no consumidor) |
| Job `gold-agenciamento` | Cloud Run Job (`us-central1`) + Scheduler `gold-agenciamento-diario` **seg–sex 09:00** (Brasília); atualiza as duas tabelas **tudo ou nada** (D16); código do commit `75bbf3c` |
| Alerta | política "gold-agenciamento falhou" → e-mail (testado em 21/10) |
| Git / GitHub | repositório privado `https://github.com/CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-` (criado em 22/10/2026, branch `main`). Deploy por `git clone` no Cloud Shell; o `.env` fica fora. Commit e push só quando o Caio pedir |

Detalhe da produção (conta de serviço, permissões, execuções, ids): `deploy/gcp_setup.md`, seção "Estado da produção".

## Pendências

| # | Pendência | Quem |
|---|---|---|
| 1 | ✅ 1ª execução automática conferida: 22/10/2026 09:02 (Brasília), SLA gravada | — |
| 2 | Conferir a 1ª execução automática com as duas tabelas (23/10/2026 09:00): `_processado_em` das duas ≈ 23/10 12:0x UTC e iguais entre si (mesma transação); nenhuma linha ERROR/WARNING no log. Depois: **próximas tabelas gold** (o Caio traz os temas). Lembrete: o calendário de feriados está copiado igual na SLA, na entrada diária e na validação dela — mudar nos três juntos | Claude (leitura) a pedido; Caio + Claude |
| 3 | ✅ Repositório no GitHub criado e deploy trocado por `git clone` (22/10/2026) | — |
| 4 | Relatório/dash/site de SLA lendo a tabela — **em outro projeto** | Caio |
| 5 | Levar à equipe `docs/melhorias_processo.md` (meta de SLA, dono de cada status, hábitos no monday, coluna "Motivo da volta") | Caio |
| 6 | Quando a equipe definir a meta (L1): ajustar `alerta_dias_uteis_cliente` (hoje 10, provisório) no SELECT | Claude + deploy |
| 7 | Variação `gld_agenciamento_2026_sla_projetos` (totais por projeto) — rascunho em `sql/rascunhos/`, não aprovada | a decidir |
| 8 | Candidatas sem depender da equipe: responsável na época de cada passo (L4), complexidade/urgência (L7), carga da equipe (L8) | a decidir |
| 9 | Revisão do Codex (22/10/2026), ainda abertas: **A7** — o job autorizar pela marca de lote concluído da silver (labels `lote_*` da foto diária), não só pela data; **SLA** — reconciliar o número de projetos com o recorte (hoje só "> 0"); **P1/P2** — testes sintéticos das regras e do job, identificador da execução, calendário de feriados numa definição só (hoje copiado em 3 SQLs), cadastro único das tabelas, alerta de carga que não aconteceu; o `validacao.replace(destino, novo)` do job troca texto, não SQL (um comentário ou literal com o nome completo da tabela também seria trocado — hoje só há a ocorrência do `FROM`); `TABELAS` diferente da produção só avisa (D16), não impede | a decidir |

## Onde está cada coisa

| Para | Leia |
|---|---|
| visão geral, convenções, decisões D1–D16, próximos passos, histórico | `docs/PRD.md` |
| a tabela SLA: como ler, pipeline, 36 colunas, regras R1–R23, números, validação, limitações | `docs/tabelas/gld_agenciamento_2026_sla_movimentos.md` |
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
   `docs/tabelas/<tabela>.md` (ficha, a partir de `_modelo.md`). `deploy/criar_<tabela>.sql` é **gerado** por
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

# PRD: Camada gold do board Agenciamento 2026 (monday.com)

| | |
|---|---|
| **Responsável** | Caio Barroso (dados) |
| **Situação** | **Em produção**: `gld_agenciamento_2026_sla_movimentos` (desde 21/10/2026) e `gld_agenciamento_entrada_diaria` (desde 22/10/2026), atualizadas juntas pelo job `gold-agenciamento` (seg–sex 09:00, tudo ou nada); alerta por e-mail testado; código no GitHub (D17). Estado e operação: [`deploy/gcp_setup.md`](../deploy/gcp_setup.md) |
| **Última revisão** | 21/10/2026 |
| **Projeto GCP** | `gglobo-viu-dados-hdg-prd` (BigQuery `US`) |
| **Dataset de destino** | `gold_monday` (variável `local_dataset_gold` no `.env`) |
| **Projeto anterior** | `../PPD-SILVER-MONDAY` — gera as silvers de origem; PRD em `../PPD-SILVER-MONDAY/docs/PRD.md` |
| **Documentos** | **retomada: [CLAUDE.md](../CLAUDE.md)** · [fontes](fontes.md) · [fichas das tabelas](tabelas/) · [melhorias de processo](melhorias_processo.md) · [implantação e produção](../deploy/gcp_setup.md) · [README](../README.md) |
| **Obsidian** | `B Trabalho/VIU Agenciamento/Projetos/B016 Gold Monday - Agenciamento 2026.md` |

## 1. O que é este projeto

O board **Backlog 2026 | Agenciamento** do monday.com já tem uma base tratada no BigQuery (camada silver, projeto
`PPD-SILVER-MONDAY`): uma linha por projeto (`slv_agenciamento_2026_itens`) e um evento por linha do histórico
(`slv_agenciamento_2026_log`).

Este projeto é o **pipeline da camada gold**: tabelas prontas para análise e BI, construídas a partir dessas silvers,
cada uma com propósito, grão, colunas e regras documentadas. As tabelas são construídas **uma de cada vez** com o
responsável: tema → colunas → regras → SQL → validação → aprovação → criação.

```text
bronze (monday) ──> silver (PPD-SILVER-MONDAY, job silver-monday 08:30)
                      ├─ slv_agenciamento_2026_itens
                      └─ slv_agenciamento_2026_log
                            │
                            ▼
                    gold (este projeto, job gold-agenciamento seg–sex 09:00)
                      └─ gld_agenciamento_2026_sla_movimentos  ──> Power BI
```

## 2. Fontes (só leitura)

| Variável no `.env` | Tabela | Uma linha por | Linhas (21/10/2026) |
|---|---|---|---|
| `board_agenciamento_itens` | `silver_monday.slv_agenciamento_2026_itens` | projeto (item do board) | 5.467 |
| `board_agenciamento_log` | `silver_monday.slv_agenciamento_2026_log` | evento do histórico (partição `data_alteracao`) | 178.151 |

Colunas por assunto: [fontes.md](fontes.md). Chave comum: `projeto_id` (estável, inclusive na migração de 03/09/2026).

**Já existem no `gold_monday` e não são deste projeto** (nada aqui escreve nelas):

| Tabela | Dono | O que faz |
|---|---|---|
| `gld_agenciamento_2026_qualidade` | job `silver-monday` | foto do dia das correções e avisos por projeto e coluna |
| `gld_agenciamento_2026_pendencias_diaria` | job `silver-monday` | foto diária das pendências de preenchimento |
| `bloq_*` | job `transform-monday` | outro board (Marcas & Bloqueios) |

## 3. Entregáveis

| # | Tabela | Uma linha por | Para que serve | Ficha | Situação |
|---|---|---|---|---|---|
| 1 | `gld_agenciamento_2026_sla_movimentos` | passagem de um projeto por um status (`projeto_id` + `passo`) | SLA por status e por fase (equipe, cliente, standby), em horas corridas e úteis; em aberto e alerta; retrabalho, reabertura, fechamento sem entrega; trabalho fora do expediente | [ficha](tabelas/gld_agenciamento_2026_sla_movimentos.md) | 🚀 em produção (21/10/2026) |
| — | `gld_agenciamento_2026_sla_projetos` | projeto | totais de SLA por projeto (variação) | rascunho em `sql/rascunhos/` | 📝 ideia |

Situações: 📝 em definição · 🧪 SQL em validação · ✅ aprovada · 🚀 criada no BigQuery.

## 4. Convenções do pipeline

1. **Nome:** `gold_monday.gld_agenciamento_2026_<tema>`; o tema diz o grão (ex.: `sla_movimentos`, `sla_projetos`).
2. **Arquivos por tabela** (o nome do arquivo é o nome da tabela):
   - `sql/<tabela>.sql` — o SELECT (só leitura), com as regras comentadas pelo ID;
   - `sql/esquemas/<tabela>.csv` — colunas, tipos e descrições (vão para o BigQuery);
   - `deploy/criar_<tabela>.sql` — **gerado** por `python tools/gerar_deploy.py` (não editar à mão);
   - `sql/validacoes/<tabela>.sql` — verificações pós-criação (toda linha deve dar `ok = TRUE`);
   - `docs/tabelas/<tabela>.md` — a ficha: grão, pipeline, colunas, regras, números, validação, limitações.
3. **Regras determinísticas**, lidas só das silvers; não recalcular o que a silver já resolve (`projeto_id`, talento,
   marca, datas reais). Mudança de regra da silver é feita no `PPD-SILVER-MONDAY`.
4. **Parâmetros** de negócio (limites, horários) ficam no CTE `parametros` no início do SELECT.
5. **Rastreio:** toda tabela leva `_processado_em`, `projeto_id` e, quando fizer sentido, `link_projeto`; labels
   `projeto=ppd-golden-agenciamento-monday`, `camada=gold`, `board`, `origem`, `tipo`.
6. **GCP corporativo:** o Claude só consulta (metadados, amostras, dry-run). Criação de tabelas, views, permissões e
   agendamentos é feita pelo Caio, com o comando entregue pronto e explicado.

## 5. Como cada tabela é construída

1. **Tema e grão:** o que a tabela responde, quem usa, uma linha por quê.
2. **Colunas** a partir de [fontes.md](fontes.md).
3. **Regras** com ID na ficha; cada decisão registrada com data.
4. **SQL** em `sql/<tabela>.sql`; custo por dry-run.
5. **Validação:** grão único, contagens, reconciliação com a silver, exemplos conferidos à mão com link.
6. **Aprovação** do responsável → esquema em CSV → `tools/gerar_deploy.py` → criação pelo Caio → validação.
7. **Atualização diária** pelo job `gold-agenciamento`.

## 6. Decisões

| # | Data | Decisão | Motivo |
|---|---|---|---|
| D1 | 21/10/2026 | Fontes: as duas silvers do `.env`; destino: `gold_monday` | definido no `.env` |
| D2 | 21/10/2026 | Uma tabela por vez, com colunas e regras aprovadas pelo Caio antes do SQL | pedido do responsável |
| D3 | 21/10/2026 | Decisões e histórico neste PRD; o detalhe de cada tabela na sua ficha | rastreabilidade |
| D4 | 21/10/2026 | Consumidor principal: **Power BI**; modelo amigável a BI, que também serve a um site de relatórios no futuro | um modelo para os dois usos |
| D5 | 21/10/2026 | **Tabelas materializadas**, recriadas inteiras a cada execução; view só para recortes leves sobre uma gold | as silvers mudam uma vez por dia; foto consistente; Power BI mais rápido; custo previsível |
| D6 | 21/10/2026 | Prefixo `gld_agenciamento_2026_` | padrão das gold existentes |
| D7 | 21/10/2026 | Atualização por um **job próprio** (`gold-agenciamento`, Cloud Run Job), no padrão do `silver-monday`: roda depois da silver, confere a silver do dia, valida antes de gravar, alerta em falha; conta de serviço própria (leitura nas silvers, escrita só nas suas tabelas) | dependência explícita da silver; não mexer no job em produção |
| D8 | 21/10/2026 | GitHub criado pelo Caio ao final; até lá, arquivos locais (`.gitignore` já tira o `.env`) | histórico desde o início |
| D9 | 21/10/2026 | Primeira gold: **SLA** | pedido do responsável |
| D10 | 21/10/2026 | SLA em **uma tabela só** com todas as movimentações e os atributos do projeto em cada linha; totais por projeto ficam para uma variação | simples para o Power BI; nada se perde |
| D11 | 21/10/2026 | Nome **`gld_agenciamento_2026_sla_movimentos`** | o nome diz o grão; deixa `…_sla_projetos` para a variação |
| D12 | 21/10/2026 | Materialização da SLA: **tabela** (`CREATE OR REPLACE`, cluster `projeto_id, status_atual`, sem partição); sem view por enquanto | cálculo pesado (calendário, janelas, 178 mil eventos) feito uma vez por dia; foto consistente com `_processado_em` único; leitura rápida e barata no Power BI. Uma view refaria tudo a cada atualização do relatório sem ganho, porque as silvers só mudam uma vez por dia |
| D13 | 21/10/2026 | Esquema (colunas, tipos, descrições) em CSV e comando de criação **gerado** do SELECT + CSV | uma fonte só; descrições aparecem no BigQuery e no Power BI |
| D14 | 21/10/2026 | Job **`gold-agenciamento`** (Cloud Run Job, `job/main.py`) agendado **seg–sex 09:00** (Brasília): confere a silver do dia (espera até 30 min) → calcula numa tabela temporária → roda a validação → só então troca o conteúdo numa transação (DELETE + INSERT, esquema e descrições ficam). Conta de serviço `gold-agenciamento` com leitura só nas duas silvers e escrita só na tabela gold; alerta por e-mail. Deploy pelo Cloud Shell com um zip (`tools/empacotar.py`), sem Git por enquanto | a silver termina ≈ 08:33; falha não deixa tabela pela metade nem errada; permissões mínimas; o Caio vai incluir mais tabelas antes de publicar no GitHub |
| D15 | 22/10/2026 | **`gld_agenciamento_entrada_diaria`**: uma tabela só com os cards criados por data × grupo de input × tipo × família (boards 2024–2026), sem linhas com zero; famílias **marcadas, não filtradas**, pelo mesmo método (nome e marca, como a silver) nos três anos; data estimada (saída − 5 dias úteis, feriados da SLA) separada em `quantidade_estimada`; de 2024-10-01 até ontem | previsão de demanda: recortes (grupo, família, com/sem estimados) e calendário completo ficam com quem consome; critério igual nos três anos evita quebra falsa na série |
| D16 | 22/10/2026 | Job **tudo ou nada**: calcula e valida todas as tabelas de `TABELAS` na mesma sessão e só então troca o conteúdo de todas numa única transação; `TABELAS` diferente de `TABELAS_PRODUCAO` gera aviso WARNING; linha de validação com `esperado = 'aviso'` vira WARNING sem bloquear. Atualização de tabela existente sem mudança de esquema é pelo job (valida antes de publicar), não pelo `criar_…sql` | revisão do Codex: com duas tabelas, uma falha deixaria publicação parcial; um deploy com lista desatualizada tiraria uma tabela da atualização sem falhar |
| D17 | 22/10/2026 | Código no GitHub: repositório privado `CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-`, branch `main`; deploy por `git clone` no Cloud Shell (zip e `tools/empacotar.py` retirados); `.env` fora do Git | fecha D8: duas tabelas prontas; histórico versionado e deploy reproduzível a partir de um commit |

## 7. Próximos passos

| # | Passo | Quem | Situação |
|---|---|---|---|
| 1 | Implantar (tabela, conta de serviço, job, ensaio, 1ª carga, agendamento 09:00, alerta e teste do alerta) | Caio, no Cloud Shell | ✅ 21/10/2026 |
| 2 | Conferir a 1ª execução agendada (22/10, 09:02: SLA gravada) e a 1ª com as duas tabelas (23/10 09:00) | Caio / Claude (leitura) | ✅ 22/10; 23/10 pendente |
| 3 | Conectar o Power BI à tabela | Caio | pendente |
| 4 | Levar à equipe as definições e hábitos de [melhorias_processo.md](melhorias_processo.md) | Caio | pendente |
| 5 | Novas tabelas gold: `gld_agenciamento_entrada_diaria` (D15) implantada em 22/10/2026; próximas, o Caio traz os temas | Caio + Claude | ✅ 1ª; demais a definir |
| 6 | ✅ Repositório no GitHub criado em 22/10/2026 (D17) | Caio | feito |

## 8. Em aberto

| # | Pergunta | Por que importa |
|---|---|---|
| Q5 | Site de relatórios (HTML/JS/CSS no GCP): quando, para quem e com que login? | projeto à parte; dados internos exigem acesso autenticado (ex.: IAP) e leitura só das gold por um backend |
| ~~Q6~~ | ~~Horário do job e falha da silver~~ | ✅ D14: 09:00 seg–sex; se a silver não chegar em 30 min, o job falha sem gravar e alerta (a tabela fica com a carga anterior; dá para rodar à mão depois) |

## 9. Histórico

| Data | O que mudou |
|---|---|
| 21/10/2026 | Estrutura do projeto, PRD inicial e catálogo das fontes |
| 21/10/2026 | Decisões D4–D8 (Power BI, tabelas materializadas, prefixo, job próprio, GitHub ao final) |
| 21/10/2026 | Construção da SLA (D9, D10) com o Caio: regras R1–R22 na ficha |
| 21/10/2026 | Revisão e organização do pipeline: nome final (D11), tabela (D12), esquema em CSV e deploy gerado (D13), validação 16/16, melhorias de processo |
| 21/10/2026 | Job `gold-agenciamento` (D14): código, imagem e roteiro de implantação; Q6 fechada |
| 21/10/2026 | **Implantado** pelo Caio no Cloud Shell: tabela criada (14.776 linhas, validação 16/16), conta de serviço, job, ensaio, 1ª carga (21:16 UTC), agendamento seg–sex 09:00 e alerta (teste recebido por e-mail) |
| 22/10/2026 | 1ª execução automática do job (09:02, SLA gravada). Nova tabela `gld_agenciamento_entrada_diaria` (D15) construída com o Caio a partir dos ensaios da `demanda_diaria` (descartada antes de ir ao BigQuery); validação 20/20 sem gravar; `job/main.py` aceita tabela sem `projeto_id`; aguarda aprovação e implantação |
| 22/10/2026 | Entrada diária **aprovada** (prioridade de famílias, de-para de outputs antigos, aviso de tipos novos, colunas de calendário). Revisão do Codex (8 achados, todos conferidos; nenhum ocorria nos dados): job tudo ou nada (D16); SLA com R23 e R10 antes de R9/R22 (histórico idêntico ao de produção); validações mais fortes nas duas tabelas; trava por board histórico. 2ª revisão do Codex: apto para implantar; ajustes finais (teto do calendário da validação, trava sem "ontem", ROLLBACK explícito no job, textos). Pendentes: A7 (marcador de lote da silver) e melhorias P1/P2 |
| 22/10/2026 | Repositório no GitHub (D17): primeiro commit `75bbf3c` com as duas tabelas; deploy passa a `git clone`; zip e `tools/empacotar.py` retirados |
| 22/10/2026 | **Implantado** pelo Caio: `gld_agenciamento_entrada_diaria` criada e validada; permissões; job tudo-ou-nada com as duas tabelas; ensaio e carga real (19:08 Brasília: SLA 14.838 linhas, entrada 1.826). Agendamento seg–sex 09:00 passa a atualizar as duas |

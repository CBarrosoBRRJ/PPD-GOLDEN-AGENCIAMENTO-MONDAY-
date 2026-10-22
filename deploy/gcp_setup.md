# Implantação no GCP — job `gold-agenciamento`

Cloud Run Job + Cloud Scheduler (seg–sex 09:00, Brasília) + conta de serviço mínima + alerta por e-mail, no mesmo padrão
do `silver-monday`. O código vai ao **Cloud Shell** por `git clone` do repositório privado
`https://github.com/CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-` (desde 22/10/2026; antes era um zip). Sem segredo:
o job só lê as silvers e grava as suas tabelas gold; o `.env` fica fora do Git.

O que o job faz em cada execução (`job/main.py`): confere que as silvers diárias foram processadas **hoje** (espera
até 30 min) → calcula **todas** as tabelas de `TABELAS` em temporárias da mesma sessão → roda as validações de todas →
só se todas passarem, troca o conteúdo de todas numa **única transação** (`DELETE` + `INSERT`; esquema e descrições
ficam). Qualquer falha: nada gravado em nenhuma tabela, execução marcada como falha, e-mail de alerta. Se `TABELAS`
vier diferente da lista de produção (`TABELAS_PRODUCAO` no `job/main.py`), o log registra um aviso WARNING.

## Estado da produção (implantado em 21/10/2026 pelo Caio, conta corporativa, Cloud Shell)

| Item | Estado |
|---|---|
| Tabela | `gold_monday.gld_agenciamento_2026_sla_movimentos` — criada às 18:1x (Brasília); 14.776 linhas, 3.095 projetos; 36 colunas com descrição; validação 16/16 |
| Conta de serviço | `gold-agenciamento@gglobo-viu-dados-hdg-prd.iam.gserviceaccount.com`: `roles/bigquery.jobUser` no projeto; `roles/bigquery.dataViewer` em `silver_monday.slv_agenciamento_2026_itens` e `slv_agenciamento_2026_log`; `roles/bigquery.dataEditor` na tabela gold; `roles/run.invoker` no job |
| Job | Cloud Run Job `gold-agenciamento` (`us-central1`), 1 CPU, 1 GiB, timeout 45 min, 1 nova tentativa; `TABELAS=gld_agenciamento_2026_sla_movimentos`, `EXIGIR_SILVER_DO_DIA=true`, `ESPERA_SILVER_MIN=30`, `TZ=America/Sao_Paulo` |
| Execuções de 21/10 | ensaio `gold-agenciamento-klklx` (16/16, nada gravado); 1ª carga `gold-agenciamento-bxhq2` (21:16 UTC, 14.776 linhas); teste do alerta `gold-agenciamento-6ts2n` (falha forçada, nada gravado, e-mail recebido) |
| Agendamento | Cloud Scheduler `gold-agenciamento-diario`: `0 9 * * 1-5`, `America/Sao_Paulo` — 1ª execução automática 22/10/2026 09:00. Ordem do dia: bronze 08:00 → silver 08:30 → **gold 09:00** |
| Alerta | política "gold-agenciamento falhou" (`alertPolicies/12083430023858162253`), canal de e-mail dos jobs bronze e silver |

## Atualizar o job (quando um SQL ou o código mudar)

1. No computador: `python tools/gerar_deploy.py` (se mudou SELECT ou esquema); commit e push para o GitHub.
2. No Cloud Shell (a primeira vez pede o login no GitHub: `gh auth login` → GitHub.com → HTTPS → login pelo
   navegador com a conta `CBarrosoBRRJ`; o Cloud Shell guarda a credencial). Depois:

```bash
gcloud config set project gglobo-viu-dados-hdg-prd && gcloud auth list   # conta ativa: caio.barroso@viu.com.br
gh auth status || gh auth login                                           # só na 1ª vez (ou se expirou)
cd ~ && rm -rf ~/PPD-GOLDEN-AGENCIAMENTO-MONDAY \
  && git clone https://github.com/CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-.git PPD-GOLDEN-AGENCIAMENTO-MONDAY \
  && cd ~/PPD-GOLDEN-AGENCIAMENTO-MONDAY && git log --oneline -1       # conferir que é o commit esperado
PROJECT=gglobo-viu-dados-hdg-prd; REGION=us-central1; SA=gold-agenciamento@$PROJECT.iam.gserviceaccount.com
```

3. Se o **esquema** mudou (coluna nova, tipo, nome), recriar a tabela e **dar de novo** a escrita da conta do job
   (recriar apaga a permissão da tabela):

```bash
bq query --use_legacy_sql=false --location=US < deploy/criar_gld_agenciamento_2026_sla_movimentos.sql
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataEditor" $PROJECT:gold_monday.gld_agenciamento_2026_sla_movimentos >/dev/null && echo ok
```

4. Implantar e ensaiar. `TABELAS` traz **sempre a lista completa** de produção (a mesma de `TABELAS_PRODUCAO` no
   `job/main.py`); uma lista menor tira a tabela que faltar da atualização. A vírgula exige o separador `^@^`:

```bash
gcloud run jobs deploy gold-agenciamento --source . --region=$REGION --service-account=$SA \
  --tasks=1 --max-retries=1 --task-timeout=45m --memory=1Gi --cpu=1 \
  --set-env-vars="^@^GCP_PROJECT_ID=$PROJECT@BQ_LOCATION=US@BQ_DATASET_GOLD=gold_monday@TABELAS=gld_agenciamento_2026_sla_movimentos,gld_agenciamento_entrada_diaria@EXIGIR_SILVER_DO_DIA=true@ESPERA_SILVER_MIN=30@TZ=America/Sao_Paulo" \
  --labels="projeto=ppd-golden-agenciamento-monday,camada=gold"
gcloud run jobs execute gold-agenciamento --region=$REGION --wait --args=--dry-run
```

## Tabela nova

1. SELECT, esquema, validação e ficha (README, "Como criar ou atualizar uma tabela"); `python tools/gerar_deploy.py`;
   commit, push e `git clone` no Cloud Shell (acima).
2. Criar a tabela: `bq query --use_legacy_sql=false --location=US < deploy/criar_<tabela>.sql` e rodar a validação
   (`bq query --use_legacy_sql=false --location=US --format=pretty < sql/validacoes/<tabela>.sql`).
3. Permissões da conta do job: `roles/bigquery.dataEditor` na tabela nova e `roles/bigquery.dataViewer` em cada fonte
   nova (`bq add-iam-policy-binding ...`, como acima).
4. Incluir a tabela em `TABELAS`, separadas por vírgula. A vírgula exige outro separador no gcloud:
   `--set-env-vars="^@^GCP_PROJECT_ID=$PROJECT@BQ_LOCATION=US@BQ_DATASET_GOLD=gold_monday@TABELAS=tabela_a,tabela_b@EXIGIR_SILVER_DO_DIA=true@ESPERA_SILVER_MIN=30@TZ=America/Sao_Paulo"`
   no deploy (passo 4 acima). Se a fonte nova não for uma das duas silvers, incluir a checagem de frescor dela em
   `FONTES` no `job/main.py` — **só se for diária**: fonte de carga única (como `slv_agenciamento_2024_itens` e
   `_2025_itens`) nunca é "de hoje" e travaria o job.

### Pendente: `gld_agenciamento_entrada_diaria` (aprovada em 22/10/2026; aguarda o Caio implantar)

Ficha: [docs/tabelas/gld_agenciamento_entrada_diaria.md](../docs/tabelas/gld_agenciamento_entrada_diaria.md). Rodar um
bloco por vez no Cloud Shell, conferindo a saída antes do próximo.

```bash
# 0) no Cloud Shell: conta, login no GitHub (1ª vez) e clone do repositório
gcloud config set project gglobo-viu-dados-hdg-prd && gcloud auth list   # conta ativa: caio.barroso@viu.com.br
gh auth status || gh auth login                                           # GitHub.com > HTTPS > navegador (CBarrosoBRRJ)
cd ~ && rm -rf ~/PPD-GOLDEN-AGENCIAMENTO-MONDAY \
  && git clone https://github.com/CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-.git PPD-GOLDEN-AGENCIAMENTO-MONDAY \
  && cd ~/PPD-GOLDEN-AGENCIAMENTO-MONDAY && git log --oneline -1
PROJECT=gglobo-viu-dados-hdg-prd; REGION=us-central1; SA=gold-agenciamento@$PROJECT.iam.gserviceaccount.com
```

```bash
# 1) criar a tabela (já com a carga de hoje) e validar: toda linha com ok = true
bq query --use_legacy_sql=false --location=US < deploy/criar_gld_agenciamento_entrada_diaria.sql
bq query --use_legacy_sql=false --location=US --format=pretty --max_rows=50 < sql/validacoes/gld_agenciamento_entrada_diaria.sql
```

```bash
# 2) permissões da conta do job: escrita na tabela nova; leitura das duas silvers de carga única (fontes novas)
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataEditor" $PROJECT:gold_monday.gld_agenciamento_entrada_diaria >/dev/null && echo ok
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataViewer" $PROJECT:silver_monday.slv_agenciamento_2024_itens >/dev/null && echo ok
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataViewer" $PROJECT:silver_monday.slv_agenciamento_2025_itens >/dev/null && echo ok
```

```bash
# 3) reimplantar o job com as duas tabelas (separador ^@^ por causa da vírgula) e ensaiar sem gravar
gcloud run jobs deploy gold-agenciamento --source . --region=$REGION --service-account=$SA \
  --tasks=1 --max-retries=1 --task-timeout=45m --memory=1Gi --cpu=1 \
  --set-env-vars="^@^GCP_PROJECT_ID=$PROJECT@BQ_LOCATION=US@BQ_DATASET_GOLD=gold_monday@TABELAS=gld_agenciamento_2026_sla_movimentos,gld_agenciamento_entrada_diaria@EXIGIR_SILVER_DO_DIA=true@ESPERA_SILVER_MIN=30@TZ=America/Sao_Paulo" \
  --labels="projeto=ppd-golden-agenciamento-monday,camada=gold"
gcloud run jobs execute gold-agenciamento --region=$REGION --wait --args=--dry-run
```

O agendamento (`gold-agenciamento-diario`, seg–sex 09:00) não muda: a próxima execução já atualiza as duas tabelas.
Depois, registrar em "Estado da produção" (acima), na ficha e na nota B016.

## Implantação inicial (feita em 21/10/2026 — referência)

```bash
# conta de serviço e permissões
gcloud iam service-accounts create gold-agenciamento --display-name="Gold agenciamento (Cloud Run Job)"
gcloud projects add-iam-policy-binding $PROJECT --member="serviceAccount:$SA" --role="roles/bigquery.jobUser" --condition=None --format=none
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataViewer" $PROJECT:silver_monday.slv_agenciamento_2026_itens
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataViewer" $PROJECT:silver_monday.slv_agenciamento_2026_log
bq add-iam-policy-binding --member="serviceAccount:$SA" --role="roles/bigquery.dataEditor" $PROJECT:gold_monday.gld_agenciamento_2026_sla_movimentos
# agendamento
gcloud run jobs add-iam-policy-binding gold-agenciamento --region=$REGION --member="serviceAccount:$SA" --role="roles/run.invoker" --format=none
gcloud scheduler jobs create http gold-agenciamento-diario --location=$REGION --schedule="0 9 * * 1-5" --time-zone="America/Sao_Paulo" --http-method=POST --uri="https://run.googleapis.com/v2/projects/$PROJECT/locations/$REGION/jobs/gold-agenciamento:run" --oauth-service-account-email=$SA --description="Gold agenciamento - seg a sex 09:00 (Brasilia), apos a silver"
# alerta: política "gold-agenciamento falhou" criada com gcloud alpha monitoring policies create, filtro
#   (cloud_run_job gold-agenciamento OU cloud_scheduler_job gold-agenciamento-diario) com severity>=ERROR,
#   canal de e-mail caio.barroso@viu.com.br
```

## Operação do dia a dia (Cloud Shell)

| Situação | Comando |
|---|---|
| Rodar fora do horário | `gcloud run jobs execute gold-agenciamento --region=us-central1` |
| Ensaio sem gravar | `gcloud run jobs execute gold-agenciamento --region=us-central1 --args=--dry-run` |
| Rodar sem exigir a silver do dia (ex.: fim de semana) | `... execute gold-agenciamento --region=us-central1 --update-env-vars=EXIGIR_SILVER_DO_DIA=false` |
| Ver as últimas execuções | `gcloud run jobs executions list --job=gold-agenciamento --region=us-central1 --limit=5` |
| Ver o log da última execução | `gcloud logging read 'resource.type="cloud_run_job" AND resource.labels.job_name="gold-agenciamento"' --freshness=1d --limit=40 --order=asc --format="value(timestamp,severity,jsonPayload.message,jsonPayload.verificacao,jsonPayload.ok)"` |
| Pausar / religar o agendamento | `gcloud scheduler jobs pause gold-agenciamento-diario --location=us-central1` / `... resume ...` |
| Conferir a tabela | `bq query --use_legacy_sql=false --location=US --format=pretty < sql/validacoes/gld_agenciamento_2026_sla_movimentos.sql` |

Falhou? O e-mail chega; no log, a linha `gold-agenciamento falhou: ...` diz o motivo (silver do dia não chegou em
30 min, ou qual validação falhou). A tabela continua com a carga anterior. Corrigida a causa, rodar à mão.

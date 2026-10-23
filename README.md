# PPD-GOLDEN-AGENCIAMENTO-MONDAY

Pipeline da camada **gold** do board Backlog 2026 | Agenciamento (monday.com), a partir das silvers do
`PPD-SILVER-MONDAY`. **Para retomar, comece pelo [CLAUDE.md](CLAUDE.md)** (estado, pendências, como trabalhar); o
projeto inteiro está no [PRD](docs/PRD.md).

## Tabelas

| Tabela | Grão | Ficha |
|---|---|---|
| `gold_monday.gld_agenciamento_2026_sla_movimentos` | passagem de um projeto por um status | [docs/tabelas/gld_agenciamento_2026_sla_movimentos.md](docs/tabelas/gld_agenciamento_2026_sla_movimentos.md) |
| `gold_monday.gld_agenciamento_entrada_diaria` (em produção desde 22/10/2026) | data × grupo de input × tipo de input × família | [docs/tabelas/gld_agenciamento_entrada_diaria.md](docs/tabelas/gld_agenciamento_entrada_diaria.md) |

## Estrutura

```text
CLAUDE.md                   retomada: estado, pendências, como trabalhar
.env                        fontes (silver) e dataset de destino (gold) — fora do Git
docs/
  PRD.md                    o projeto: convenções, entregáveis, decisões, próximos passos, histórico
  fontes.md                 colunas das silvers, por assunto
  melhorias_processo.md     o que definir com a equipe e melhorar no processo e nos dados
  tabelas/<tabela>.md       PRD de cada tabela gold: pergunta, memória de cálculo, regras, validação, histórico (modelo: _modelo.md)
sql/
  <tabela>.sql              SELECT de cada tabela gold (só leitura; fonte da verdade)
  esquemas/<tabela>.csv     colunas, tipos e descrições
  validacoes/<tabela>.sql   verificações pós-criação (toda linha ok = TRUE)
  rascunhos/                variações ainda não aprovadas
deploy/
  criar_<tabela>.sql        comando de criação — GERADO, não editar à mão
  descrever_<tabela>.sql    só as descrições (ALTER ... SET OPTIONS) — GERADO, não editar à mão
  gcp_setup.md              implantação e operação do job no GCP (Cloud Shell)
job/
  main.py                   job gold-agenciamento (Cloud Run Job)
tools/
  gerar_deploy.py           gera deploy/criar_*.sql a partir de sql/ e sql/esquemas/
Dockerfile, requirements.txt, .gcloudignore   imagem do job
```

## Como criar ou atualizar uma tabela

1. Alterar o SELECT (`sql/<tabela>.sql`) e, se mudar coluna, o esquema (`sql/esquemas/<tabela>.csv`).
2. Gerar o comando: `python tools/gerar_deploy.py <tabela>` (sem argumento, gera todas).
3. **Validar antes de publicar**: rodar a validação sobre o SELECT novo (sem gravar) e conferir que toda linha sai com
   `ok = TRUE` — ou implantar o job e rodar o ensaio `--dry-run` (calcula e valida, não grava).
4. Publicar:
   - **tabela nova**: rodar `deploy/criar_<tabela>.sql` uma vez (cria já com os dados) e a validação;
   - **tabela existente sem mudança de esquema**: só reimplantar o job; a próxima execução troca o conteúdo depois de
     validar (não usar o `criar_…sql`, que publica antes de validar). Se mudaram **descrições**, rodar também
     `deploy/descrever_<tabela>.sql` (gerado): o job não atualiza descrições;
   - **mudança de esquema**: recriar pelo `criar_…sql` e dar de novo as permissões (deploy/gcp_setup.md, passo 3).
5. Registrar a mudança na ficha e no PRD.

## Atualização diária (job `gold-agenciamento`)

Cloud Run Job agendado **seg–sex 09:00** (Brasília), depois da silver: confere a silver do dia, calcula e valida
todas as tabelas e só então troca o conteúdo de todas numa única transação (tudo ou nada). Código em `job/main.py`;
imagem pelo `Dockerfile`; implantação e operação em [deploy/gcp_setup.md](deploy/gcp_setup.md). Em produção desde
21/10/2026 (SLA) e, com as duas tabelas e tudo ou nada, desde 22/10/2026 (estado real em `deploy/gcp_setup.md`,
"Estado da produção"). O código vai ao Cloud Shell por `git clone` do repositório
privado `CBarrosoBRRJ/PPD-GOLDEN-AGENCIAMENTO-MONDAY-` (GitHub); o `.env` fica fora do Git.

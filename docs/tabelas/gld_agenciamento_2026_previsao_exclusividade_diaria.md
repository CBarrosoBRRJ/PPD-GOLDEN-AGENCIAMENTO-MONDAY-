# `gold_monday.gld_agenciamento_2026_previsao_exclusividade_diaria`

PRD da tabela: por que existe, o que entrega, como cada número é calculado (memória de cálculo), regras com ID e data,
validação com números e histórico. Inclui as derivações mensais (views) na seção 8.

| | |
|---|---|
| **Situação** | 🧪 SQL em validação (26/10/2026): validação 11/11 ok sobre o SELECT; a mensal recalculada por cima dela = a antiga tabela mensal (0 diferenças nos 20 números). Criação e job pendentes |
| **Pergunta** | Quantos pedidos de Inbound e de Mercado entraram em cada dia, e quantos eram de talentos exclusivos, não exclusivos e sem talento? |
| **Por que existe** | A previsão de demanda do site de relatórios (página Previsão, `ml/dados.py`) monta essas séries lendo a silver; na gold, ficam num lugar só, com o total de cada dia conferido contra a diária. Diária, e não só mensal (decisão do Caio, 26/10/2026): serve a modelos diários e semanais, e a mensal passa a ser a soma dela (uma regra só, sem segunda cópia do SELECT) |
| **O que esperamos fazer** | Séries da previsão (Inbound, Mercado, Mercado exclusivos e não exclusivos), diárias e mensais; 6ª tabela do plano `docs/PLANO_GOLD_POR_VISUAL.md` do PPD-AGENCIAMENTO-SLA. A série mensal total (tabela 5 do plano) não foi criada: é a `gld_agenciamento_entrada_diaria` agrupada por mês |
| **Saída esperada** | 2 linhas por dia (Inbound, Mercado), todo dia de 1º/jan até ontem, inclusive fins de semana e feriados (com zero) — 596 linhas em 26/10/2026 |
| **Uma linha por** | dia × tipo |
| **Quem usa** | site de relatórios do Agenciamento (previsão de demanda) |
| **Fontes** | `silver_monday.slv_agenciamento_2026_itens` (diária) |
| **Materialização** | tabela (cluster `data, tipo`) · atualização: job `gold-agenciamento`, seg–sex 09:00, depois da `gld_agenciamento_entrada_diaria` e da `gld_agenciamento_2026_talentos_ano` (a validação confere contra as duas) |
| **Arquivos** | SELECT `sql/gld_agenciamento_2026_previsao_exclusividade_diaria.sql` · esquema `sql/esquemas/…_diaria.csv` · criação `deploy/criar_…_diaria.sql` e descrições `deploy/descrever_…_diaria.sql` (gerados) · validação `sql/validacoes/…_diaria.sql` |
| **Custo** | ≈ 0,3 MB por execução (a mensal, com o mesmo SELECT, deu 0,29 MB no dry-run de 26/10/2026) |

## 1. Como ler

- `exclusivos + nao_exclusivos + sem_talento = total`; o total é igual à diária (`quantidade + quantidade_estimada`) do
  mesmo dia e tipo.
- Todo dia aparece, com zero quando não há pedido: a série já vem com o calendário completo (diferente das outras
  golds). `dia_util = FALSE` em sábado, domingo e feriado (calendário da diária).
- A série diária por exclusividade é ruidosa (Inbound ≈ 5 pedidos por dia útil, divididos em 3): boa para somar por
  semana ou para modelo diário; para gráfico, prefira a mensal.
- Só o ano de ontem (board 2026). Para a série longa (desde 2024-10), usar a `gld_agenciamento_entrada_diaria`; ela
  não tem exclusividade.

## 2. Pipeline (ordem do SQL) — memória de cálculo

| # | Etapa (CTE) | O que faz | Regras |
|---|---|---|---|
| 1 | `parametros`, `anos`, `pascoa`, `feriados` | 1º/jan e ontem; calendário completo da diária | R3, R4 |
| 2 | `pedidos` | data de entrada, tipo e exclusividade de cada card ativo | R1, R2, R5, R21, T1 |
| 3 | `calendario` | todo dia do ano até ontem × Inbound, Mercado; dia útil | PD1, PD2, P2 |
| 4 | `contagem` | conta por dia × tipo | P2 |
| 5 | final | calendário + contagem (zero onde não há pedido) | PD1 |

| Coluna | Cálculo |
|---|---|
| `exclusivos` | `COUNTIF(exclusivo)` |
| `nao_exclusivos` | `COUNTIF(NOT exclusivo)` |
| `sem_talento` | `COUNTIF(exclusivo IS NULL)` |
| `dia_util` | seg–sex e fora do calendário sem expediente |

## 3. Colunas (8)

`data`, `tipo`, `dia_util`, `exclusivos`, `nao_exclusivos`, `sem_talento`, `total`, `_processado_em` — tipos e
descrições em `sql/esquemas/gld_agenciamento_2026_previsao_exclusividade_diaria.csv`.

## 4. Regras

| ID | Regra (com o motivo) | Decidido em |
|---|---|---|
| R1–R5, R21, T1 | As da `gld_agenciamento_2026_talentos_ano` (calendário completo da diária) | ficha dela |
| P2 | Só Inbound e Mercado, as séries da previsão (D48 do site) | site, D48 |
| PD1 | Calendário completo: todo dia de 1º/jan até ontem, nos dois tipos, com zero sem pedido. Diferente das outras golds (que não gravam zeros): aqui a série é o produto e a mensal nunca fica com buraco — o que também evita a validação "sem buraco" falhar em janeiro | Caio, 26/10/2026 |
| PD2 | `dia_util` = seg–sex fora do calendário sem expediente, para os modelos separarem fim de semana e feriado | Caio, 26/10/2026 |
| P1, P3 | Na mensal (view): `completo` = o mês terminou até o último dia da base (ontem na carga); mês como DATE (1º dia) | Claude + Caio, 26/10/2026 |

## 5. Log de cada execução

Informativo: dias úteis no ano e feriados de seg a sex; pedidos em dia não útil; Mercado por mês (exclusivos / não
exclusivos / sem talento).

## 6. Validação e números

Ensaio de 26/10/2026 (SELECT validado direto, contra a `gld_agenciamento_entrada_diaria` de produção da carga das 09:01;
a `talentos_ano` ainda não existe no BigQuery e entrou pelos números do SELECT dela no mesmo dia): **11/11 ok**.

| Verificação | Resultado |
|---|---|
| chave dia × tipo única; calendário completo | 596 linhas = 298 dias × 2 tipos |
| contagens nulas ou negativas; partes somam o total; data fora do ano | 0; 0; 0 |
| sábado ou domingo marcado como dia útil | 0 |
| total = diária por dia × tipo | 0 diferenças |
| partes ≤ `talentos_ano` | 2.546 de 3.451 · 1.673 de 1.980 · 82 de 125 |
| dias úteis no ano · feriados de seg a sex | 199 · 13 |
| pedidos em dia não útil | 31 |
| **mensal (view) = antiga tabela mensal** | 0 diferenças nos 20 números (Mercado set/2026 477 = 194 + 272 + 11; Inbound set/2026 129) |

## 7. Pontos de atenção

| Ponto | Efeito |
|---|---|
| Lê só a silver 2026 | Virada de ano: precisa da silver 2027 antes de 1º/jan; o histórico de exclusividade de 2025 não existe |
| Sem talento cresce no mês corrente | Out/2026: 32 em Mercado; pedidos novos ainda sem talento. Não ler como queda de exclusivos |
| Virada do ano nas validações | Esta tabela e a mensal passam em janeiro (calendário completo). A `talentos_ano` e a `talentos_ranking`, não — decisão pendente sobre validação tolerante no começo do ano |
| Calendário copiado | Mais uma cópia do calendário de feriados (pendência P1/P2 do CLAUDE.md) |

## 8. Derivações (views)

Não têm cálculo próprio: somam ou filtram esta tabela e por isso são sempre iguais a ela; não entram no job nem precisam
de `dataEditor`. View, e não tabela: uma tabela derivada leria a base gravada e, no job, ficaria um dia atrasada (ou
teria de copiar o SELECT inteiro). Criar **depois** da base, nesta ordem (os gerados estão em `deploy/criar_<view>.sql`,
do cadastro `VIEWS` de `tools/gerar_deploy.py`). Cada uma tem `sql/<view>.sql`, `sql/esquemas/<view>.csv` e
`sql/validacoes/<view>.sql`.

| View | O que é | Grão |
|---|---|---|
| `gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal` | soma por mês da diária, com `completo` (o contrato `previsao_exclusividade` do site) | mês × tipo |
| `gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_inbound` | a mensal com `tipo = 'Inbound'`, sem a coluna `tipo` | mês |
| `gold_monday.gld_agenciamento_2026_previsao_exclusividade_mensal_mercado` | a mensal com `tipo = 'Mercado'`, sem a coluna `tipo` | mês |

Validação da mensal: a da antiga tabela mensal (sem buraco, = diária por mês × tipo, partes ≤ `talentos_ano`), com
mês sem pedido aceito (total 0). Dos recortes: linhas = mensal com o tipo, 0 diferenças coluna a coluna. Quem lê as
views precisa de leitura no dataset `gold_monday`.

## 9. Histórico

| Data | O que mudou |
|---|---|
| 26/10/2026 | Criada (como tabela mensal `gld_agenciamento_2026_previsao_exclusividade`) a partir do contrato `previsao_exclusividade` da auditoria do site, com mês DATE, `completo` e calendário completo; validação 11/11 ok sobre o SELECT |
| 26/10/2026 | Derivações só Inbound e só Mercado, pedidas pelo Caio, como views |
| 26/10/2026 | Por decisão do Caio, a **diária** vira a tabela base (`…_diaria`, calendário completo e `dia_util`, PD1–PD2) e a mensal vira view sobre ela (`…_mensal`); os recortes passam a `…_mensal_inbound` e `…_mensal_mercado`. Validação 11/11 ok; a mensal recalculada = a antiga em todos os 20 números |

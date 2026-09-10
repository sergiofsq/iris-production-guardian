# Registro de pendências (VERIFY_REQUIRED) — Fase 0

> Este arquivo é o registro único de pendências previsto em
> `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` (seção 4, "Uso obrigatório
> de VERIFY_REQUIRED"). Cada item abaixo só é fechado com evidência observada,
> não com leitura de documentação isolada.

## Ambiente validado em 09/09/2026

- Host: macOS 26.6.2, arm64 (Apple Silicon), Docker 29.4.0.
- Imagem usada: `intersystems/iris-community:latest-cd` (multi-arch, build
  22/07/2026) → `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers)
  2026.2 (Build 221U)`, confirmado via `$zversion` dentro do container.
- **Achado não presumido**: o repositório `intersystems/iris-community-arm64`
  (sem o multi-arch) está abandonado desde meados de 2025. Sua licença
  Community embutida expirou e a instância recusa iniciar
  (`Invalid Community Edition license, may have exceeded core limit`).
  Não usar esse repositório neste projeto.
- Container: `iris-guardian`, portas `51972` (SuperServer, host→1972 no container) e `53773` (webserver, host→52773 no container) — alteradas em 10/09/2026 para não colidir com Cache/Ensemble/IRIS de outra VM (`1972`, `57772`, `57773`)
  (webserver), volume nomeado `iris-guardian-data` montado em `/durable`
  com `ISC_DATA_DIRECTORY=/durable` (durable %SYS — dados sobrevivem a
  `docker rm`). Usuário de teste: `demo`.
- **Achado não presumido**: um volume Docker nomeado recém-criado pertence a
  `root` por padrão; a instância IRIS roda como `irisowner` (uid/gid
  `51773`) e falha ao iniciar (`Target exists but is not writeable:
  /durable/`) até o volume ser ajustado com
  `docker run --rm --user root --entrypoint chown -v <volume>:/durable
  intersystems/iris-community:latest-cd -R 51773:51773 /durable` antes do
  primeiro start. Confirmado após o ajuste: `/durable/mgr/IRIS.DAT` e
  demais arquivos de banco presentes no volume, de propriedade de
  `irisowner`.

## VR-001 — Vector Search na Community Edition

- Questão: o tipo `VECTOR` e as funções de similaridade (`TO_VECTOR`,
  `VECTOR_COSINE`) estão disponíveis na Community Edition, sem licença
  adicional?
- Evidência necessária: teste mínimo no ambiente real.
- Como verificado: via `%SQL.Statement` no namespace `USER`:
  - `CREATE TABLE VecTest (id INT, v VECTOR(DOUBLE, 3))` → executado com
    sucesso.
  - `SELECT TO_VECTOR('1,2,3', DOUBLE)` → retornou um vetor real.
  - `SELECT VECTOR_COSINE(TO_VECTOR('1,2,3',DOUBLE), TO_VECTOR('1,2,4',DOUBLE))`
    → retornou `0.99146013398366727997`.
- Estado: **confirmado**. Nenhuma restrição de licença observada.
- Impacto: viabiliza busca vetorial nativa no IRIS para o RAG Assistant,
  sem depender de banco vetorial externo.

## VR-002 — Foreign Table na Community Edition

- Questão: `CREATE FOREIGN SERVER` / `CREATE FOREIGN TABLE` exigem edição
  paga (a feature de licença nº 27 aparece na documentação de
  `%SYSTEM.License`, mas não havia confirmação para Community Edition)?
- Evidência necessária: teste mínimo no ambiente real.
- Como verificado: via `%SQL.Statement` no namespace `USER`:
  - `CREATE FOREIGN SERVER TestFS2 FOREIGN DATA WRAPPER JDBC CONNECTION
    'dummyconn'` → preparado com sucesso (o wrapper `Postgres`, testado
    primeiro, falhou por nome inválido, não por licença).
  - `CREATE FOREIGN TABLE TestFT (id INT, name VARCHAR(50)) SERVER TestFS2`
    → status de sucesso (`1`).
- Estado: **confirmado**. Nenhuma restrição de licença observada.
- Impacto: viabiliza o bônus de Foreign Table (+1) sem exceção de edição.

## Decisão de identidade visual — 09/09/2026

- Fonte: `ImagemMatriz.png` (fornecida pelo proprietário) continha a arte do
  produto "IRIS Guardian" e, no rodapé, o wordmark oficial registrado
  "InterSystems® | DATA | INTELLIGENCE | ACTION".
- Risco identificado: usar o wordmark oficial da InterSystems dentro de um
  app de submissão de comunidade pode sugerir endosso oficial não
  autorizado.
- Decisão do proprietário: manter apenas a arte própria do produto (escudo +
  "IRIS Guardian" + tagline + ícones), removendo o rodapé com o wordmark
  oficial.
- Implementado: `assets/iris-guardian-logo.png` (recorte de
  `ImagemMatriz.png`, sem o rodapé InterSystems®) é o logo a usar nas
  páginas da aplicação. `ImagemMatriz.png` original permanece no repositório
  apenas como fonte/histórico, não deve ser usado em páginas públicas.
- Paleta de marca extraída por amostragem de pixel da própria arte (não de
  ativos da InterSystems) e registrada como tokens CSS em
  `assets/css/iris-guardian-theme.css`: navy `#0a1965`/`#102f8b`, teal
  `#0fd1c4`/`#01989c`, roxo de acento `#3a2fb5`. Tipografia usa pilha de
  fontes de sistema, não a fonte proprietária da InterSystems.

## VR-003 — IntegratedML (provider AutoML) na Community Edition

- Questão: `CREATE MODEL` / `TRAIN MODEL` / `PREDICT` (IntegratedML,
  provider padrão `%AutoML`) funcionam nesta instância sem licença
  adicional?
- Evidência necessária: teste mínimo no ambiente real, com dados sintéticos
  rotulados.
- Como verificado: via `%SQL.Statement` no namespace `USER`, tabela
  `MLTest` (32 linhas sintéticas, 2 features numéricas + `label` A/B):
  - `CREATE TABLE MLTest (...)` → executado com sucesso.
  - `DROP MODEL IF EXISTS MLTestModel` / `CREATE MODEL MLTestModel
    PREDICTING (label) FROM MLTest` → `%SQLCODE 0`, sucesso (camada
    SQL/COS do IntegratedML funciona).
  - `TRAIN MODEL MLTestModel` → `%SQLCODE -186`, mensagem `%ML Provider
    'AutoML' is not available on this instance`.
  - Causa raiz confirmada (não presumida): a classe `%ML.AutoML.Provider`
    (`%ImportPackage`) exige os módulos Python `iris_automl.automl`,
    `numpy` e `pandas` via Embedded Python (`%SYS.Python`). Dentro do
    container, `python3 -c "import iris_automl"` e `import sklearn` /
    `import pandas` falham com `ModuleNotFoundError`. Busca em todo o
    filesystem (`find / -iname "*automl*"`) não encontrou nenhum arquivo,
    wheel ou requirements relacionado ao AutoML embarcado na imagem
    `intersystems/iris-community:latest-cd` (ARM64, 2026.2). `pip index
    versions iris_automl` / `pip download iris_automl` confirmam que o
    pacote não está no PyPI público — é proprietário da InterSystems e não
    é distribuído com esta imagem/edição.
- Estado: **confirmado — bloqueado neste ambiente**. Não é restrição de
  licença SQL (a criação do modelo é aceita); é ausência do motor de
  treino Python `iris_automl` na imagem Community Edition ARM64 usada.
- Impacto: bônus IntegratedML (+3) não é viável com o container atual sem
  uma fonte oficial do pacote `iris_automl` (não localizada publicamente).
  Providers alternativos (`%H2O` exige servidor H2O externo — violaria a
  premissa de não introduzir dependências externas; `%PMML` importa um
  modelo já treinado fora do IRIS, não treina a partir dos dados do
  projeto) não atendem ao objetivo de treinar/prever dentro do IRIS sem
  dependência externa. Registrar este bônus como **fora do escopo do MVP**
  até haver decisão do proprietário ou fonte oficial do pacote.
- Artefatos de teste (`MLTest`, `MLTestModel`) removidos do namespace
  `USER` após a verificação; nenhum resíduo permanece no ambiente.

## Bônus com evidência registrada — Fase 1 (09/09/2026)

Detalhe completo em `02_FASE_1_PYPROD_INTEROPERABILITY.md`.

### Service, Process e Operation (+1)

- Prova: Production `Guardian.Production.GuardianProduction` no namespace
  `GUARDIAN`, com um host de cada tipo (`Guardian.Service.FileIncidentService`,
  `Guardian.Process.IncidentRouterProcess`, `Guardian.Operation.FileOutputOperation`).
- Evidência: mensagem `Guardian.Messages.IncidentEvent` real (`INC-001`)
  atravessou os três hosts, confirmada por (a) arquivo de saída
  `out/incident_INC-001.txt` com campos `ProcessedBy`/`ProcessedAt`
  preenchidos pelo Process, e (b) consulta SQL a `Ens.MessageHeader`
  mostrando as três transições com `Status=9` (completo).
- Estado: **confirmado**.

### Adaptador em host (+1)

- Prova: `Guardian.Service.FileIncidentService` usa
  `EnsLib.File.InboundAdapter` (lê `/durable/guardian/in`, arquiva em
  `/durable/guardian/archive`); `Guardian.Operation.FileOutputOperation` usa
  `EnsLib.File.OutboundAdapter` (grava em `/durable/guardian/out`). Ambos
  são adaptadores suportados nativamente pelo IRIS, sem dependência
  externa.
- Evidência: teste de ponta a ponta descrito acima — arquivo depositado em
  `in/` gerou corretamente o arquivo correspondente em `out/` via os dois
  adaptadores.
- Estado: **confirmado**.

### Falha controlada e recuperação (evidência do "Aceite proposto" do Monitor)

- Prova: destino da Operation (`/durable/guardian/out`) tornado
  indisponível (`chmod 555`); incidente disparado; erro real capturado em
  `Ens.MessageHeader.ErrorStatus` (`ERROR #5005: Cannot open file...`,
  `<Ens>ErrFailureTimeout` após 15s). Destino corrigido; tráfego novo
  recupera automaticamente; mensagem afetada recuperada manualmente via
  `Ens.MessageHeader.ResendMessage`.
- Evidência: roteiro reproduzível e validado duas vezes do zero em
  `docs/experiments/01_falha_recuperacao_producao.md`; detalhe completo em
  `02_FASE_1_PYPROD_INTEROPERABILITY.md` §5.
- Estado: **confirmado**. Cobre o "Aceite proposto" do Production Monitor
  (contexto, seção 2): falha rastreável até o evento original, recuperação
  visível (automática e manual).

## RAG Assistant (09/09/2026)

Detalhe completo em `04_FASE_3_RAG_ASSISTANT.md`.

### RAG funcional (item principal, 5 pontos)

- Prova: ingestão (`Guardian.RAG.Ingestion`, 79 fragmentos de 5
  documentos reais do projeto), recuperação vetorial
  (`Guardian.RAG.Query`, `VECTOR_COSINE` + `TOP 5`), geração com citação
  de fonte (`Guardian.RAG.GeminiClient`), abstenção quando a similaridade
  é baixa, página de consulta (`Guardian.UI.RAGPage`).
- Evidência: pergunta relevante ("por que o IntegratedML não funciona")
  respondida corretamente com citação da fonte certa (similaridade 0.653);
  pergunta irrelevante ("receita de bolo de chocolate") corretamente
  abstida (similaridade 0.518, abaixo do limiar de 0.58); indisponibilidade
  real da API (Gemini retornou `503`) tratada sem derrubar a aplicação.
- Estado: **confirmado**.

### Justificativa de chunking/embedding (+2)

- Prova: dimensão do embedding (768, truncada do default 3072 via
  Matryoshka representation do Gemini) e estratégia de chunking
  (parágrafo até 800 caracteres, sobreposição de 150) documentadas com
  raciocínio explícito em `04_FASE_3_RAG_ASSISTANT.md` seções 3 e 3.2.
- Reforço quantitativo (10/09/2026): comparação formal A/B contra
  chunking por janela fixa ingênua (`Guardian.RAG.Eval.RunChunkingComparison`,
  7 perguntas, mesmo texto para as duas estratégias) — parágrafo venceu
  em similaridade média nas 7 perguntas (0.709 vs 0.684), sem exceção.
  Ambas acertaram o documento certo em 100% dos casos. Ver
  `04_FASE_3_RAG_ASSISTANT.md` §7.2.
- Estado: **confirmado**, agora com evidência quantitativa além do
  raciocínio.

### Clareza do pipeline RAG (+2)

- Prova: pipeline documentado ponta a ponta (ingestão → chunking →
  embedding → armazenamento vetorial → recuperação → geração → citação →
  abstenção), com diagrama textual e cada etapa testada individualmente
  com evidência real (não apenas descrita).
- Estado: **confirmado**.

### Busca híbrida — lexical + vetorial (+3) — 10/09/2026

- Prova: índice de texto completo nativo `%iFind.Index.Basic`
  (`idxChunkTextFind`) sobre `Guardian_RAG.Chunk.ChunkText`, criado em
  `Guardian.RAG.Schema.Setup`; fundido com a busca vetorial existente via
  Reciprocal Rank Fusion (`k=60`) em `Guardian.RAG.Query.Ask`, pool de até
  15 candidatos de cada busca, TopK final 5.
- Evidência: pergunta com código de erro exato ("O que significa o erro
  #5005 no cenário de falha?") recuperou e citou corretamente o chunk
  correto (melhor similaridade 0.677, 5 fontes); pergunta irrelevante
  ("receita de bolo de chocolate") continuou corretamente abstida
  (similaridade 0.521, abaixo do limiar de 0.58) — confirma que a fusão
  híbrida não alterou a calibração de abstenção já validada, pois o gate
  usa só a similaridade vetorial pura.
- Achado registrado (não escondido): a função de ranking nativa do iFind
  (`%iFind.Rank`) não aceitou a sintaxe testada ao vivo (`Field
  'IDXCHUNKTEXTFIND' not found`); em vez de inventar uma posição de rank
  não calculada, um match lexical soma um bônus fixo equivalente a rank 1
  na fusão — simplificação honesta, documentada em
  `04_FASE_3_RAG_ASSISTANT.md` §6.
- Estado: **confirmado**.

## AI Incident Investigator (10/09/2026)

Detalhe completo em `05_FASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md`.

### Investigator funcional (item principal)

- Prova: `Guardian.Investigator.EvidenceCollector` junta saúde real
  (reaproveita `Guardian.Monitor.StatusCollector`), eventos reais de
  `Ens.MessageHeader` (com erro convertido para texto legível via
  `$System.Status.GetErrorText`) e documentação relevante (reaproveita a
  busca híbrida do RAG via `Guardian.RAG.Query.Retrieve`);
  `Guardian.Investigator.Analyzer` gera resumo/hipóteses/lacunas/próximos
  passos separando observação de hipótese, sem percentual de confiança
  inventado; `Guardian.UI.InvestigatorPage` apresenta tudo e persiste a
  investigação em `Guardian_Investigator.Investigation`.
- Evidência: investigação real de `Guardian.Operation.FileOutputOperation`
  contra o histórico do experimento de falha/recuperação da Fase 1 — 20
  eventos reais recuperados (incluindo os 3 episódios de erro `#5005`),
  análise corretamente separou observações de hipóteses, e sinalizou como
  **lacuna** (não como fato inventado) a discrepância entre saúde
  `unavailable` e `erros recentes=0`. Investigação confirmada persistida
  por consulta SQL direta.
- Estado: **confirmado**.

## Pendências ainda abertas (não testadas nesta rodada)

- WSGI e PyProd: não são pendência técnica, são conflito estrutural com a
  premissa "COS first" (seção 1.1 do contexto) — WSGI é por definição uma
  interface Python; PyProd hospeda hosts em Python. Decisão do proprietário
  registrada: não perseguir esses dois bônus, manter tudo em COS.
- Multimodelo, API pública: ainda não testados; dependem da arquitetura
  de classes que será definida nas próximas fases.

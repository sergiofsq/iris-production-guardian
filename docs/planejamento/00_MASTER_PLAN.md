# Master Plan — IRIS Production Guardian

> Documento de acompanhamento vivo: fases, dependências, decisões e
> cronograma. Fonte de verdade para escopo e premissas é
> `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`; este arquivo apenas
> rastreia progresso e aponta para onde cada decisão/evidência está
> registrada. Atualizar a cada incremento relevante, não retroativamente.

## 1. Escopo e prioridades (resumo)

MVP com três módulos — **Production Monitor**, **AI Incident Investigator**,
**RAG Assistant** — sobre InterSystems IRIS, com COS/ObjectScript como
linguagem principal e persistência exclusivamente em IRIS. Detalhe completo
em `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`, seções 1–2.

Premissa tecnológica obrigatória (contexto, seção 1.1): COS primeiro,
IRIS como único banco, Python só por limitação comprovada de COS. Nenhuma
exceção foi aplicada até aqui.

## 2. Fases e arquivos associados

| Fase | Arquivo | Status |
|---|---|---|
| Fase 0 — Setup e arquitetura | `01_FASE_0_SETUP_ARQUITETURA.md` | Infraestrutura e VRs críticos fechados. Só bônus (multimodelo/híbrida/API pública) pendentes — não bloqueiam as demais fases |
| Fase 1 — Production COS / interoperabilidade | `02_FASE_1_PYPROD_INTEROPERABILITY.md` | Objetivo principal cumprido — Service/Process/Operation com adaptador de arquivo, mensagem real ponta a ponta, cenário de falha/recuperação testado e reproduzível (`docs/experiments/01_falha_recuperacao_producao.md`). Falta apenas Business Rules (bônus opcional) |
| Fase 2 — Production Monitor / telemetria | `03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md` | Primeira versão concluída e validada visualmente pelo proprietário. Série temporal persistida fica como melhoria futura |
| Fase 3 — RAG Assistant | `04_FASE_3_RAG_ASSISTANT.md` | Completa e testada: ingestão, chunking, armazenamento vetorial, recuperação híbrida (vetorial + lexical via iFind, bônus +3, ver §4), geração com citação, abstenção calibrada, página de consulta. Validação visual concluída em 10/09/2026 (fundo/logo ajustados) |
| Fase 4 — AI Investigator / IntegratedML / API | `05_FASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md` | Não iniciada (IntegratedML já registrado como bloqueado — VR-003) |
| Fase 5 — Hardening, testes, demo | `06_FASE_5_HARDENING_TESTS_DEMO.md` | Não iniciada |
| Scorecard de evidências | `07_SCORECARD_EVIDENCIAS.md` | Ativo — atualizado a cada VR fechado |

Os arquivos de fase ainda não criados serão adicionados quando a fase
correspondente começar, não antes — evita planejamento especulativo
desatualizado.

## 3. Cronograma (até 21/09/2026)

| Datas | Trabalho e ponto de controle | Status em 09/09/2026 |
|---|---|---|
| 08–10/09 | Fase 0: ambiente, repositório, IRIS/contêineres, arquitetura, estrutura inicial do dashboard | ✅ Ambiente, VRs críticos e namespace/database prontos. Dashboard inicial coberto pelo Monitor/RAG, adiantado |
| 11–14/09 | Fase 1 + avanço da Fase 2: Production COS, hosts, simulação controlada, Monitor ligado a fontes reais | ✅ **Concluído adiantado, no dia 09/09** — Fase 1 e Fase 2 completas (ver seção 2) |
| 15–17/09 | Fases 3 e 4: corpus, embeddings, busca híbrida, Investigator | 🟡 Fase 3 (RAG) completa, adiantada, no dia 09/09. Busca híbrida (bônus) e Fase 4 (Investigator) ainda não iniciadas |
| 18–19/09 | Fase 5: API/integrações, testes, instalação limpa, documentação | Não iniciada |
| 20/09 | Demo completa, gravação, README, artigo, auditoria da matriz | README já existe (criado 09/09); gravação/artigo pendentes |
| 21/09 | Conferência final e submissão | Não iniciada |

**Leitura honesta:** o ritmo está bem adiantado em relação ao cronograma original — três fases (0, 1, 2) mais a Fase 3 (RAG) já têm versões funcionais testadas no dia 1 da janela de trabalho real. Isso é adiantamento de sequência, não validação de que não falta trabalho: bônus opcionais (Business Rules, busca híbrida, multimodelo, API pública), a Fase 4 inteira, hardening/testes formais, vídeo e artigo continuam por fazer.

`VERIFY_REQUIRED`: horário/fuso oficial de corte da submissão — não
presumir 23h59 (herdado do contexto, ainda aberto).

## 4. Decisões registradas (cronológico)

- **09/09/2026** — Ambiente Docker/IRIS validado (Community 2026.2 ARM64);
  achado: imagem `iris-community-arm64` sem multi-arch está abandonada, não
  usar. Ver `01_FASE_0_SETUP_ARQUITETURA.md` §1–2.
- **09/09/2026** — VR-001 (Vector Search) e VR-002 (Foreign Table)
  confirmados, sem restrição de licença na Community Edition.
- **09/09/2026** — Identidade visual própria definida: logo sem wordmark
  InterSystems, paleta em `assets/css/iris-guardian-theme.css`.
- **09/09/2026** — WSGI e PyProd descartados como bônus a perseguir
  (conflito estrutural com premissa COS-first, não pendência técnica).
- **09/09/2026** — VR-003 (IntegratedML/AutoML) confirmado bloqueado nesta
  imagem; bônus (+3) marcado fora do escopo do MVP.
- **09/09/2026** — Namespace `GUARDIAN` e database `GUARDIANDB` criados,
  interoperabilidade habilitada, verificados por comando. Usuário
  administrativo dedicado do projeto criado (credencial fora do Git).
- **09/09/2026** — Ambiente de desenvolvimento configurado: VS Code +
  extensão InterSystems ObjectScript, servidor nomeado `guardian-local`
  (Basic auth, HTTP, porta 53773), compilação automática ao salvar em
  `src/`. Ver `.vscode/settings.json`.
- **09/09/2026** — Fase 1 iniciada: Production
  `Guardian.Production.GuardianProduction` implementada (Service → Process
  → Operation com adaptador `EnsLib.File`), mensagem real testada ponta a
  ponta. Bônus "Service, Process e Operation" (+1) e "Adaptador em host"
  (+1) confirmados com evidência. Ver `02_FASE_1_PYPROD_INTEROPERABILITY.md`.
- **09/09/2026** — Corrigido o tipo de `TargetConfigName` para
  `Ens.DataType.ConfigName` (era `%String`) nos hosts Service e Process —
  necessário para o editor gráfico de Interoperability desenhar as
  conexões entre hosts.
- **09/09/2026** — Cenário de falha controlada e recuperação testado e
  validado duas vezes do zero (script reproduzível em
  `docs/experiments/01_falha_recuperacao_producao.md`): falha real
  (`ERROR #5005`), recuperação automática para tráfego novo, recuperação
  manual da mensagem afetada via `Ens.MessageHeader.ResendMessage`.
- **09/09/2026** — Iniciada a organização dos arquivos de entrega:
  `docs/experiments/` para roteiros reproduzíveis (uso na gravação do
  vídeo do concurso) e `README.md` (inglês, público) na raiz.
- **09/09/2026** — Fase 2 (Production Monitor) iniciada: regras de saúde
  documentadas (saudável/degradado/indisponível/desconhecido, baseadas
  apenas em fontes de dado reais confirmadas — `Ens_Config.Item`,
  `Ens.Queue`, `Ens.MessageHeader`, `Ens.Director`). Implementado
  `Guardian.Monitor.StatusCollector` (lógica), `Guardian.API.MonitorAPI`
  (REST `/api/guardian/status`) e `Guardian.UI.MonitorPage` (HTML em
  `/csp/guardian/Guardian.UI.MonitorPage.cls`). Testado contra o
  Experimento 1 (falha real): hosts corretamente mudam para `degraded`
  durante a falha. Erro real de compilação encontrado e documentado:
  `Parameter` com underscore quebra `..#NOME` (operador de concatenação
  do ObjectScript interfere no parser). Ver `03_FASE_2_...md`.
- **09/09/2026** — Fase 3 iniciada: decisão de provedor de IA (Google
  Gemini, tier gratuito — ChatGPT/Claude.ai descartados por não incluir
  API na assinatura de chat; OpenAI API sem tier gratuito confirmado;
  Cohere trocado por restrição de uso comercial). Chave armazenada em
  `Ens.Config.Credentials`. `Guardian.RAG.GeminiClient` implementado e
  testado ao vivo (embeddings 768-dim + geração). Configuração SSL de
  saída (`PublicHTTPS`) criada para HTTPS a hosts públicos.
- **09/09/2026** — Fase 3 (RAG Assistant) primeira versão completa:
  esquema `Guardian_RAG.Document`/`Chunk` (VECTOR 768-dim, DDL direto),
  chunking por parágrafo com sobreposição, corpus inicial de 79
  fragmentos (docs do próprio projeto), recuperação `VECTOR_COSINE` + top
  5, geração com citação de fonte, abstenção calibrada em 0.58 (dois
  pontos reais observados), página `Guardian.UI.RAGPage`. Erros reais
  corrigidos: `%SQL.Statement` sem `%GetLastIdentity` (usar `%ROWID`),
  acesso incorreto a propriedade de `%DynamicObject` via `$Get` (usar
  `%Get`), falso alarme de encoding (bug era só exibição de terminal,
  confirmado por hexdump), e tratamento de indisponibilidade real da API
  (503) sem derrubar a página. Ver `04_FASE_3_RAG_ASSISTANT.md`.
- **10/09/2026** — Validação visual do RAG Assistant pelo proprietário:
  aprovada, com dois ajustes. (1) Fundo azul vivo demais na primeira
  versão — corrigido para um azul médio deliberado (`#3f63a8` corpo,
  `#2f4d85` cabeçalho), cartões de conteúdo em branco para legibilidade.
  (2) Logo do produto ausente — inserida (recorte sem a tag-line,
  `assets/iris-guardian-logo-header.png`) em um "selo" branco no
  cabeçalho. Achado durante o ajuste: o tema tinha um modo escuro
  automático (`prefers-color-scheme: dark`) que reagia ao SO do usuário
  sem que todos os elementos (links de navegação) tivessem cor adaptada —
  texto escuro sobre fundo escuro, contraste ruim. Removido; paleta única
  e fixa daqui em diante, ver `assets/css/iris-guardian-theme.css`. Mesma
  correção aplicada ao `Guardian.UI.MonitorPage` para consistência visual
  entre os dois módulos (ambos agora referenciam o tema compartilhado, que
  antes existia mas nunca era de fato carregado pelas páginas). Logo
  servida como arquivo estático em `/durable/csp/guardian/` (diretório
  físico da aplicação CSP `/csp/guardian/`) via `docker cp` — não faz
  parte do volume versionado no Git, reproduzir o `docker cp` após
  recriar o container.
- **10/09/2026** — Busca híbrida implementada (bônus +3, fechando a
  pendência da Fase 3): índice `%iFind.Index.Basic` sobre
  `Guardian_RAG.Chunk.ChunkText` + Reciprocal Rank Fusion com a busca
  vetorial já existente, dentro de `Guardian.RAG.Query.Ask`. Testado ao
  vivo com pergunta contendo código de erro exato (`#5005`, recuperado e
  citado corretamente) e reconfirmada a abstenção em pergunta irrelevante
  (calibração de 0.58 intacta, pois o gate de abstenção continua baseado
  só na similaridade vetorial pura, não no score híbrido). Achado
  registrado: `%iFind.Rank` (função de ranking nativa do iFind) não
  aceitou a sintaxe esperada — decisão de usar um bônus fixo por match
  lexical em vez de inventar uma posição de rank não calculada. Ver
  `04_FASE_3_RAG_ASSISTANT.md` §6.

## 5. Registro de pendências (VERIFY_REQUIRED)

Registro único em `07_SCORECARD_EVIDENCIAS.md`. Resumo do que segue aberto:

- Interfaces de métricas/filas/logs para o Monitor.
- Business Rules (roteamento real).
- Multimodelo (formas reais de acesso por tipo).
- ~~Pesquisa híbrida (lexical + vetorial)~~ — **fechada 10/09/2026**:
  iFind + RRF em `Guardian.RAG.Query`, ver `04_FASE_3_RAG_ASSISTANT.md` §6.
- Acesso a API pública adequada.
- ~~Provedor/modelo de IA para embeddings e geração~~ — **fechado
  09/09/2026**: Google Gemini API (tier gratuito), ver
  `04_FASE_3_RAG_ASSISTANT.md`.
- Horário/fuso limite oficial da submissão.
- Interpretação de teto de bônus/multimodelo pela organização do concurso.

Fechar cada item apenas com evidência observada, registrando no scorecard.

## 6. Definition of Done (referência)

Checklist completo em `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`,
seção 11. Primeiro item com progresso real: a Production COS (Service →
Process → Operation) existe, roda, e tem cenário de falha/recuperação
testado e reproduzível. Os três módulos do MVP (Monitor, Investigator, RAG)
ainda não existem como interface própria. Reavaliar esta seção ao final de
cada fase.

## 7. Estrutura de arquivos de entrega

Organização adotada para a submissão (Open Exchange + artigo na
comunidade), consolidada em 09/09/2026, **reorganizada em 10/09/2026**
para não deixar nenhum arquivo solto na raiz do repositório (padrão do
proprietário daqui em diante — não criar mais arquivos soltos na raiz).

| Caminho | Conteúdo | Público/interno |
|---|---|---|
| `README.md` | Visão geral do projeto, instalação, como reproduzir — em inglês | Público (Open Exchange). Fica na raiz por convenção de ferramenta (GitHub/Open Exchange só renderiza automaticamente o README na raiz) |
| `package.json` | Metadados de tooling frontend (lint/format/dev server) | Público. Fica na raiz por convenção do npm |
| `docs/planejamento/` (`00_MASTER_PLAN.md` … `07_SCORECARD_EVIDENCIAS.md`, `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`) | Planejamento, decisões e evidências por fase — em português | Interno (contexto de desenvolvimento, pode acompanhar o repo como transparência do processo) |
| `docs/experiments/` | Roteiros reproduzíveis passo a passo de cada experimento controlado (falha/recuperação, futuros: carga, RAG, IntegratedML) — em português, uso direto na gravação do vídeo | Interno, mas referenciável no artigo |
| `src/Guardian/` | Código-fonte COS (classes da Production, mensagens, hosts) | Público |
| `assets/` | Identidade visual (logo, tokens CSS) | Público |
| `pessoal/` (`Estudar.txt`, `Anotações para Usuário.txt`, `Script de Apresentação V1.txt`) | Material pessoal de aprendizado/apresentação do proprietário | **Não** entra na entrega — pasta inteira no `.gitignore` |
| `Imagens/ImagemMatriz.png` | Arte-fonte do logo (ver `07_SCORECARD_EVIDENCIAS.md`) | Rastreado no git |
| `Imagens/guardian-boas-vindas.png`, `guardian-landing-hero.png`, `guardian-rag-assistant.png` | Arte ilustrativa/conceitual adicional (variações do escudo da marca — retrato, hero horizontal, composição RAG), gerada em 10/09/2026, mesmo espírito de `ImagemMatriz.png` | Rastreado no git — decisão de uso público (README/artigo/vídeo) ainda pendente, mas já versionado |
| `Imagens/Aplicacao/MonitroPage1.jpg`, `MonitroPage2.jpg` | Prints de evidência **citados por caminho** em `03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md` §4.2 e §7 (bug de locale, validação visual) | Rastreado no git — a citação no doc agora resolve para quem clonar o repo |
| `Imagens/Config/*.jpg` | Screenshots pessoais de configuração (VS Code, namespace, Production) — sem citação em nenhum doc de fase | Rastreado no git a pedido explícito do proprietário (10/09/2026: "tudo o que está na pasta do projeto precisa ser commitado") — conferido visualmente antes do commit, sem credencial exposta |
| `Imagens/Error/` (`VSCode.jpg`) | Screenshot pessoal de um erro pontual do VS Code | **Não** entra na entrega — exceção explícita do proprietário (10/09/2026) à regra de "commitar tudo", agora no `.gitignore` |
| `Imagens/.DS_Store`, `**/Thumbs.db` | Lixo de sistema operacional (Finder/Explorer) | No `.gitignore` — não versionado mesmo com a regra acima, por não ser conteúdo do projeto |

Pendente: artigo da comunidade (português, com tags exigidas — ver
contexto seção 5), vídeo explicativo, e o próprio conteúdo do `README.md`
(criado nesta sessão, ver `04_...`/commits).

**10/09/2026 — política de versionamento revisada:** proprietário pediu
que tudo dentro da pasta do projeto seja commitado, com duas exceções
explícitas, ambas no `.gitignore`: (1) `pessoal/` — contém credencial em
texto puro em `Anotações para Usuário.txt` (`guardian`/`guardian`) que o
proprietário confirmou **não** deve ir para o git, mantendo a regra de
"sem segredo versionado"; (2) `Imagens/Error/` — screenshot pessoal de um
erro pontual, excluído a pedido direto do proprietário.

## 8. Próximo passo imediato

Validação visual (RAG e Monitor) e busca híbrida concluídas em
10/09/2026 — decisão do proprietário foi manter o Gemini free tier por
enquanto (token instável, mas sem troca de provedor por ora). Fase 3
está com todos os itens não-bônus fechados; resta só como bônus opcional
mais corpus/comparação de chunking (ver `04_FASE_3_RAG_ASSISTANT.md` §4).
Próxima decisão: avançar para a Fase 4 (AI Incident Investigator, ainda
não iniciada) ou continuar reforçando a Fase 3.

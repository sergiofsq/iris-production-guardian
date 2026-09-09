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
| Fase 0 — Setup e arquitetura | `01_FASE_0_SETUP_ARQUITETURA.md` | Em andamento — infraestrutura e VRs críticos fechados; bônus (multimodelo/híbrida/API pública) pendentes |
| Fase 1 — Production COS / interoperabilidade | `02_FASE_1_PYPROD_INTEROPERABILITY.md` | Objetivo principal cumprido — Service/Process/Operation com adaptador de arquivo, mensagem real ponta a ponta, cenário de falha/recuperação testado e reproduzível (`docs/experiments/01_falha_recuperacao_producao.md`). Falta apenas Business Rules (bônus opcional) |
| Fase 2 — Production Monitor / telemetria | `03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md` | Primeira versão no ar — REST API + página HTML, testada contra falha real. Falta validação visual no navegador pelo proprietário e série temporal persistida |
| Fase 3 — RAG Assistant | `04_FASE_3_RAG_ASSISTANT.md` | Não iniciada |
| Fase 4 — AI Investigator / IntegratedML / API | `05_FASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md` | Não iniciada (IntegratedML já registrado como bloqueado — VR-003) |
| Fase 5 — Hardening, testes, demo | `06_FASE_5_HARDENING_TESTS_DEMO.md` | Não iniciada |
| Scorecard de evidências | `07_SCORECARD_EVIDENCIAS.md` | Ativo — atualizado a cada VR fechado |

Os arquivos de fase ainda não criados serão adicionados quando a fase
correspondente começar, não antes — evita planejamento especulativo
desatualizado.

## 3. Cronograma (até 21/09/2026)

| Datas | Trabalho e ponto de controle | Status em 09/09/2026 |
|---|---|---|
| 08–10/09 | Fase 0: ambiente, repositório, IRIS/contêineres, arquitetura, estrutura inicial do dashboard | Ambiente, VRs críticos e namespace/database prontos. Estrutura inicial do dashboard **ainda não iniciada**. |
| 11–14/09 | Fase 1 + avanço da Fase 2: Production COS, hosts, simulação controlada, Monitor ligado a fontes reais | Fase 1 iniciada adiantada (09/09): três hosts + adaptador provados. Simulação de falha e Fase 2 ainda não iniciadas |
| 15–17/09 | Fases 3 e 4: corpus, embeddings, busca híbrida, Investigator | Não iniciada |
| 18–19/09 | Fase 5: API/integrações, testes, instalação limpa, documentação | Não iniciada |
| 20/09 | Demo completa, gravação, README, artigo, auditoria da matriz | Não iniciada |
| 21/09 | Conferência final e submissão | Não iniciada |

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
  (Basic auth, HTTP, porta 52773), compilação automática ao salvar em
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

## 5. Registro de pendências (VERIFY_REQUIRED)

Registro único em `07_SCORECARD_EVIDENCIAS.md`. Resumo do que segue aberto:

- Interfaces de métricas/filas/logs para o Monitor.
- Business Rules (roteamento real).
- Multimodelo (formas reais de acesso por tipo).
- Pesquisa híbrida (lexical + vetorial).
- Acesso a API pública adequada.
- Provedor/modelo de IA para embeddings e geração (decisão do proprietário:
  custo, acesso, dados).
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
comunidade), consolidada em 09/09/2026:

| Caminho | Conteúdo | Público/interno |
|---|---|---|
| `README.md` | Visão geral do projeto, instalação, como reproduzir — em inglês | Público (Open Exchange) |
| `00_MASTER_PLAN.md` … `07_SCORECARD_EVIDENCIAS.md` | Planejamento, decisões e evidências por fase — em português | Interno (contexto de desenvolvimento, pode acompanhar o repo como transparência do processo) |
| `docs/experiments/` | Roteiros reproduzíveis passo a passo de cada experimento controlado (falha/recuperação, futuros: carga, RAG, IntegratedML) — em português, uso direto na gravação do vídeo | Interno, mas referenciável no artigo |
| `src/Guardian/` | Código-fonte COS (classes da Production, mensagens, hosts) | Público |
| `assets/` | Identidade visual (logo, tokens CSS) | Público |
| `Estudar.txt`, `Anotações para Usuário.txt`, `Imagens/` | Material pessoal de aprendizado do proprietário | **Não** entra na entrega — manter fora do commit/publicação |

Pendente: artigo da comunidade (português, com tags exigidas — ver
contexto seção 5), vídeo explicativo, e o próprio conteúdo do `README.md`
(criado nesta sessão, ver `04_...`/commits).

## 8. Próximo passo imediato

Validação visual do Production Monitor no navegador pelo proprietário
(`http://localhost:52773/csp/guardian/Guardian.UI.MonitorPage.cls`). Depois
disso, decidir entre reforçar o Monitor (série temporal persistida) ou
avançar para a Fase 3 (RAG Assistant).

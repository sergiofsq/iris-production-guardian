# Fase 0 — Setup e Arquitetura

> Consolida o inventário real do ambiente, as decisões de arquitetura tomadas
> e o estado das pendências técnicas até **09/09/2026**. Detalhe de evidência
> técnica de cada teste fica em `07_SCORECARD_EVIDENCIAS.md`; este documento
> não repete os comandos, apenas resume resultado e decisão. Regras de não
> alucinação e o registro `VERIFY_REQUIRED` seguem `IRIS-Production-Guardian-
> CONVERSATION-CONTEXT.md` (seção 4).

## 1. Inventário do ambiente (observado, não presumido)

| Item | Valor confirmado |
|---|---|
| Host | macOS 26.6.2, arm64 (Apple Silicon) |
| Docker | Docker Desktop, motor local (`docker info` responde) |
| Imagem IRIS | `intersystems/iris-community:latest-cd` (multi-arch, build 22/07/2026) |
| Versão IRIS | `IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2 (Build 221U)`, confirmado via `$ZVERSION` |
| Edição | Community |
| Python embarcado | 3.12.3 (Embedded Python, `%SYS.Python`) |

**Achado não presumido:** o repositório `intersystems/iris-community-arm64`
(sem o multi-arch) está abandonado desde meados de 2025; sua licença
Community embutida expirou e a instância recusa iniciar. Não usar esse
repositório neste projeto — usar `intersystems/iris-community:latest-cd`.

## 2. Container e persistência

- Container: `iris-guardian`.
- Portas publicadas: `1972` (SuperServer), `52773` (webserver/Management Portal).
- Volume nomeado `iris-guardian-data`, montado em `/durable`, com
  `ISC_DATA_DIRECTORY=/durable` → dados sobrevivem a `docker rm`.
- **Achado não presumido:** um volume Docker nomeado recém-criado pertence a
  `root`; a instância roda como `irisowner` (uid/gid `51773`) e falha ao
  iniciar até o volume ser ajustado com `chown -R 51773:51773 /durable`
  antes do primeiro start. Confirmado após o ajuste.
- Layout confirmado sob `/durable/mgr/`: cada database vive em subpasta
  própria (`/durable/mgr/user/IRIS.DAT` para o namespace `USER`,
  `/durable/mgr/IRIS.DAT` na raiz para `%SYS`). Convenção aplicada ao
  database do projeto (seção 3).

## 3. Namespace e database do projeto

Criados em 09/09/2026 via Management Portal (`Sistema > Configuração >
Namespaces > Novo Namespace`):

| Item | Valor |
|---|---|
| Namespace | `GUARDIAN` |
| Database (Globais e Rotinas) | `GUARDIANDB`, único banco para os dois — mesmo padrão do namespace `USER` |
| Diretório do database | `/durable/mgr/guardian/` (subpasta dedicada, fora da raiz de `/durable/mgr/`) |
| Interoperabilidade (Productions) | Habilitada |

Verificação por linha de comando (não só pela tela do portal):

```
##class(Config.Namespaces).Exists("GUARDIAN")        → 1
##class(Config.Databases).Exists("GUARDIANDB")        → 1
##class(%EnsembleMgr).IsEnsembleNamespace("GUARDIAN") → 1
```

O namespace `GUARDIAN` é o namespace de trabalho do projeto a partir de
agora. Os testes de VR-001/002/003 (seção 4) foram executados antes da
criação deste namespace, no namespace `USER`, e seus artefatos de teste já
foram removidos de lá — não há resíduo em `USER` nem em `GUARDIAN`.

## 4. Usuários e credenciais

- O usuário `demo` esperado a partir das variáveis de ambiente
  `IRIS_USERNAME`/`IRIS_PASSWORD` do container **não foi criado** por essa
  via nesta imagem — achado não presumido, divergente da expectativa
  inicial.
- Login administrativo inicial feito como `_SYSTEM`; senha padrão alterada
  pelo proprietário.
- Criado usuário dedicado ao projeto (role `%All`) para uso corrente no
  Management Portal e no desenvolvimento. Credencial não documentada neste
  arquivo nem em nenhum arquivo versionado, conforme a regra de não incluir
  segredos no Git (seção 10 do contexto). Mantida apenas em memória local do
  agente/proprietário; migrar para mecanismo de segredo apropriado
  (`.env` não versionado + `.gitignore`) antes de qualquer automação que
  precise dela.

## 5. Resultados dos testes VERIFY_REQUIRED (Fase 0)

Detalhe completo, comandos e evidência em `07_SCORECARD_EVIDENCIAS.md`.

| ID | Recurso | Estado | Resultado |
|---|---|---|---|
| VR-001 | Vector Search (`VECTOR`, `TO_VECTOR`, `VECTOR_COSINE`) | confirmado | Funciona na Community Edition, sem licença adicional. Viabiliza busca vetorial nativa para o RAG Assistant. |
| VR-002 | Foreign Table (`CREATE FOREIGN SERVER`/`FOREIGN TABLE`) | confirmado | Funciona na Community Edition, sem licença adicional. Viabiliza o bônus Foreign Table (+1). |
| VR-003 | IntegratedML (provider `%AutoML`) | confirmado — bloqueado | `CREATE MODEL` funciona (camada SQL/COS ok); `TRAIN MODEL` falha (`SQLCODE -186`). Causa raiz: pacote Python proprietário `iris_automl` ausente na imagem Community ARM64 e não disponível no PyPI público. Bônus (+3) fora do escopo do MVP até haver decisão do proprietário ou fonte oficial do pacote. |

## 6. Decisões de arquitetura registradas

1. **COS/ObjectScript primeiro** para lógica de negócio, interoperabilidade
   e orquestração — conforme premissa obrigatória (seção 1.1 do contexto).
   Nenhuma exceção aplicada até aqui.
2. **Persistência exclusivamente em InterSystems IRIS** — nenhum banco
   externo foi introduzido; Vector Search nativo cobre a necessidade de
   busca vetorial do RAG sem depender de banco vetorial externo (VR-001).
3. **WSGI e PyProd descartados como bônus a perseguir** — não são pendência
   técnica, são conflito estrutural com a premissa COS-first (WSGI é
   interface Python por definição; PyProd hospeda hosts em Python).
   Decisão do proprietário já registrada no scorecard.
4. **IntegratedML fora do escopo do MVP** (VR-003) — providers alternativos
   (`H2O` exige servidor externo, conflita com "sem dependência externa";
   `PMML` só importa modelo já treinado fora do IRIS) não atendem ao
   objetivo de treinar/prever dentro do IRIS.
5. **Identidade visual própria** — logo sem o wordmark oficial da
   InterSystems (risco de sugerir endosso não autorizado), paleta extraída
   da arte própria, tokens em `assets/css/iris-guardian-theme.css`.
6. **Namespace/database dedicados ao projeto** (`GUARDIAN`/`GUARDIANDB`),
   interoperabilidade habilitada desde a criação, para suportar a Production
   COS da Fase 1.

## 7. Riscos identificados

- **IntegratedML bloqueado** (VR-003): se o proprietário quiser reivindicar
  esse bônus, será necessário localizar uma fonte oficial e lícita do
  pacote `iris_automl` para esta imagem/edição, ou trocar de imagem/edição —
  ainda não avaliado.
- **Prazo**: cronograma de 21/09/2026 (seção 7 do contexto) não tem folga
  grande; itens de bônus com dependência incerta (multimodelo, híbrida, API
  pública) devem receber prova de viabilidade curta antes de investimento
  maior.
- **Credenciais locais**: usuário `guardian` criado sem ainda haver um
  mecanismo formal de gestão de segredo (`.env`/`.gitignore`) no repositório
  — resolver antes de qualquer script de automação that dependa dele.

## 8. Pendências ainda abertas (não testadas)

Herdadas da lista inicial do contexto (seção 4) e ainda sem teste/decisão:

- Interfaces de métricas/filas/logs realmente disponíveis para o Monitor.
- Business Rules (roteamento real, não condicionais disfarçadas).
- Multimodelo — formas reais de acesso, por tipo.
- Pesquisa híbrida (lexical + vetorial).
- Acesso a API pública adequada para o bônus correspondente.
- Modelos e chaves de IA (provedor de embeddings/geração) — decisão do
  proprietário pendente (custo, acesso, dados).
- Horário/fuso limite oficial da submissão (21/09/2026) — não presumir
  23h59.
- Interpretação de teto de bônus/multimodelo pela organização do concurso.

## 9. Critério de saída da Fase 0

- [x] Ambiente IRIS real inventariado e documentado.
- [x] Container/volume durável validados e reproduzíveis (passo de `chown`
      documentado).
- [x] Namespace e database do projeto criados e verificados por comando.
- [x] VR-001, VR-002, VR-003 fechados com evidência.
- [ ] Multimodelo, busca híbrida e API pública — prova mínima de viabilidade
      pendente.
- [ ] Estrutura inicial da interface web (shell dos três módulos) — ainda
      não iniciada.

**Estado da Fase 0: em andamento.** Infraestrutura e VRs críticos ao MVP
fechados; itens de bônus com dependência incerta seguem abertos e não
bloqueiam o início da Fase 1 (Production COS), que pode começar em
paralelo.

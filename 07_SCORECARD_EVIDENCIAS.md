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
- Container: `iris-guardian`, portas `1972` (SuperServer) e `52773`
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

## Pendências ainda abertas (não testadas nesta rodada)

- IntegratedML: disponibilidade citada em fontes públicas para Community
  Edition (até 20 cores), mas ainda sem teste mínimo (`CREATE MODEL` /
  `TRAIN MODEL` / `PREDICT`) neste container. Estado: aberto.
- WSGI e PyProd: não são pendência técnica, são conflito estrutural com a
  premissa "COS first" (seção 1.1 do contexto) — WSGI é por definição uma
  interface Python; PyProd hospeda hosts em Python. Decisão do proprietário
  registrada: não perseguir esses dois bônus, manter tudo em COS.
- Multimodelo, busca híbrida (lexical + vetorial), API pública: ainda não
  testados; dependem da arquitetura de classes que será definida nas
  próximas fases.

# Fase 3 — RAG Assistant

## 1. Decisão de provedor de IA (proprietário, 09/09/2026)

Pendência aberta desde a Fase 0 (contexto, seção 4) fechada: **Google
Gemini API**, tier gratuito.

- Descartado ChatGPT/Claude.ai: assinatura de chat (Plus/Pro) **não**
  inclui acesso à API — são produtos e faturamento separados. Confirmado
  ao vivo: a API da OpenAI não tem tier gratuito (nem embeddings nem
  chat) em 09/09/2026.
- Descartado Cohere (escolha inicial): trial key tem restrição explícita
  de "não uso em produção/comercial"; Gemini free tier não tem essa
  restrição.
- **Ressalva de dados aceita pelo proprietário**: no tier gratuito do
  Gemini, o conteúdo enviado pode ser usado pelo Google para melhorar
  produtos (diferente do tier pago). Só indexar documentação já pública/
  autorizada.
- Chave de API armazenada em `Ens.Config.Credentials` (`SystemName =
  "Gemini"`) — nunca em arquivo do repositório. Ver
  `01_FASE_0_SETUP_ARQUITETURA.md` §4 para o padrão de gestão de
  segredos do projeto.

## 2. Conectividade real verificada (09/09/2026)

Testado via `curl` direto contra a API antes de escrever qualquer classe
COS, com a chave real:

| Endpoint | Modelo | Resultado |
|---|---|---|
| `POST /v1beta/models/gemini-embedding-001:embedContent` | `gemini-embedding-001` | Vetor real retornado. Dimensão default: 3072. Com `outputDimensionality: 768`, retorna 768 — usado esse valor (ver justificativa seção 3) |
| `POST /v1beta/models/gemini-2.5-flash:generateContent` | `gemini-2.5-flash` | **Erro 404 real**: `"This model ... is no longer available to new users ... use models/gemini-3.6-flash"` — nome de modelo desatualizado no conhecimento do agente, corrigido pela própria resposta da API |
| `POST /v1beta/models/gemini-3.6-flash:generateContent` | `gemini-3.6-flash` | Resposta real gerada em português, coerente com o prompt de teste |

**Nota registrada, não escondida**: `gemini-3.6-flash` é um modelo com
raciocínio interno (`thoughtsTokenCount` no uso reportado) — consome mais
tokens que uma resposta direta. Aceitável para o volume de uma demo；
reavaliar se afetar o tier gratuito em uso intenso.

## 3. Escolha de dimensão do embedding (768) — justificativa

A API do Gemini usa representação Matryoshka: o mesmo modelo aceita
truncar a saída via `outputDimensionality` sem precisar de outro modelo.
Escolhido **768** em vez do default (3072) por:

- Custo de armazenamento e de cálculo do `VECTOR_COSINE` no IRIS
  proporcional à dimensão — 768 é 4x mais leve que 3072 para um corpus de
  demonstração pequeno, sem necessidade de precisão de produção em larga
  escala.
- 768 é uma dimensão amplamente usada/testada em embeddings de uso geral
  (comparável a modelos como `text-embedding-ada-002`), reduzindo risco de
  comportamento atípico.

Registrar no artigo do concurso como resposta ao critério "Justificativa
de chunking/embedding" (+2).

### Comandos de setup (reproduzíveis)

```objectscript
;; namespace %SYS — configuracao SSL para HTTPS de saida
Set obj = ##class(Security.SSLConfigs).%New()
Set obj.Name = "PublicHTTPS"
Set obj.Type = 0
Set obj.CAFile = "/etc/ssl/certs/ca-certificates.crt"
Set obj.VerifyPeer = 1
Set obj.Enabled = 1
Do obj.%Save()

;; namespace GUARDIAN — credencial da API (SUBSTITUIR pelo valor real,
;; nunca commitar a chave de verdade)
Set obj = ##class(Ens.Config.Credentials).%New()
Set obj.SystemName = "Gemini"
Set obj.Username = "gemini-api"
Set obj.Password = "<CHAVE_REAL_AQUI>"
Do obj.%Save()
```

## 3.1 Cliente COS implementado e testado (09/09/2026)

`Guardian.RAG.GeminiClient` — `Embed(texto)` e `Generate(prompt)`, via
`%Net.HttpRequest`, chave lida de `Ens.Config.Credentials` em tempo de
execução (nunca em código-fonte). Exigiu criar uma configuração SSL de
saída (`Security.SSLConfigs`, nome `PublicHTTPS`, `CAFile =
/etc/ssl/certs/ca-certificates.crt` — bundle padrão do sistema já
presente na imagem) para permitir HTTPS de saída para hosts públicos.

Testado chamando os métodos **a partir do COS** (não só via curl):
- `Embed("teste de conectividade a partir do COS")` → vetor real, 768
  dimensões.
- `Generate("...")` → texto real gerado pela API, em português.

**Investigação de encoding (não é bug):** a exibição no terminal
(`docker exec -i iris session`) mostra acentos como `�`, mas
`$Length("coração")` retorna `7` (contagem lógica correta de caracteres,
não de bytes UTF-8) — confirma que a string está armazenada corretamente
internamente; o problema é só do charset do terminal usado para depurar,
não da aplicação. Não precisou de correção no código.

## 3.2 Esquema de dados, chunking, ingestão e consulta (09/09/2026)

- **Esquema**: `Guardian_RAG.Document` (Source, Title, Version,
  CollectedAt) e `Guardian_RAG.Chunk` (DocumentId, ChunkIndex, ChunkText,
  `Embedding VECTOR(DOUBLE, 768)`, EmbeddingModel, CreatedAt) — criadas
  via DDL direto (`Guardian.RAG.Schema`), mesma abordagem validada no
  VR-001/002, não via `Property` de classe persistente (evita sintaxe de
  tipo de vetor em ObjectScript não verificada).
- **Chunking** (`Guardian.RAG.Ingestion`): agrupamento por parágrafo
  (separador `\n\n`) até 800 caracteres, com parágrafos maiores que isso
  quebrados em janelas deslizantes com 150 caracteres de sobreposição.
  Justificativa: parágrafos preservam unidades de sentido; 800 caracteres
  equilibra contexto suficiente por fragmento com precisão de recuperação
  para os documentos deste projeto (Markdown técnico, parágrafos curtos a
  médios); sobreposição reduz perda de informação em cortes no meio de
  uma explicação.
- **Corpus inicial**: os próprios documentos de fase do projeto
  (`00_MASTER_PLAN.md` a `04_FASE_3_RAG_ASSISTANT.md`) — conteúdo próprio,
  já autorizado, e diretamente relevante ao domínio ("como o IRIS
  Production Guardian funciona"). 79 fragmentos gerados a partir de 5
  documentos.
- **Consulta** (`Guardian.RAG.Query`): embedding da pergunta, `TOP 5` por
  `VECTOR_COSINE`, prompt instruindo o modelo a responder só com o
  contexto fornecido e citar a fonte. Abstenção se a melhor similaridade
  ficar abaixo de `MinSimilarity`.
- **Calibração do limiar de abstenção**: iniciado em 0.5, ajustado para
  **0.58** após dois pontos reais observados — pergunta relevante
  ("por que o IntegratedML não funciona") = 0.653; pergunta irrelevante
  ("receita de bolo de chocolate") = 0.518 (passaria do filtro em 0.5).
  Ainda uma heurística com poucos pontos, não estatisticamente validada —
  calibração melhor fica como trabalho futuro com um conjunto de avaliação
  maior.
- **Página**: `Guardian.UI.RAGPage` (`/csp/guardian/Guardian.UI.RAGPage.cls`)
  — formulário simples (GET, sem JS), a lógica toda em COS.

### Erros reais encontrados e corrigidos

1. `%SQL.Statement` não tem método `%GetLastIdentity()` (não existe na
   API real). `LAST_IDENTITY()` via SQL também não funciona quando
   chamado num `%SQL.Statement` **separado** do INSERT (testado e
   confirmado vazio). Corrigido usando `%ROWID` do próprio resultset do
   INSERT, que funciona de forma confiável.
2. `$Select($IsObject($Get(tResp.error)):...)` — `$Get` não se aplica a
   propriedade de `%DynamicObject` (erro `Class '%Library.DynamicObject'
   does not support MultiDimensional operations`). Corrigido usando
   `tResp.%Get("error")`, a forma correta de acessar uma chave que pode
   não existir num objeto dinâmico.
3. **Falso alarme de encoding, registrado para não repetir o
   investigativo**: depurar a API via `iris session` (terminal Docker sem
   TTY real) mostra acentos corrompidos como espaços ou `�`/`Ã§`. Um
   hexdump da resposta HTTP real (via `curl`, bytes crus) confirmou UTF-8
   perfeitamente válido de ponta a ponta — o problema era só a exibição
   do terminal de depuração, não a aplicação. **Não presumir bug de
   encoding a partir de saída de terminal — sempre conferir os bytes
   reais (hexdump) ou o `$Length`/códigos de caractere antes de alterar
   código por causa disso.**
4. **Resiliência a indisponibilidade do modelo**: a API do Gemini
   retornou um `503 UNAVAILABLE` real durante os testes ("high demand").
   Sem tratamento, isso derrubava a página com o erro genérico do CSP.
   Adicionado `Try/Catch` em `Guardian.UI.RAGPage` para mostrar uma
   mensagem clara em vez de travar — consistente com o requisito do MVP
   de que indisponibilidade do modelo não deve impedir o uso da
   aplicação.

## 6. Busca híbrida (lexical + vetorial) — 10/09/2026

Bônus +3 implementado: `Guardian.RAG.Query.Ask` agora funde dois
rankings independentes antes de montar o TopK final.

- **Índice lexical**: `idxChunkTextFind`, um índice `%iFind.Index.Basic`
  (full-text search nativo do IRIS) sobre `Guardian_RAG.Chunk.ChunkText`,
  criado em `Guardian.RAG.Schema.Setup` — verificado ao vivo que funciona
  na Community Edition sem licença extra (mesma família de achado do
  VR-001/VR-002). Busca via predicado SQL `%FIND search_index(...)`.
- **Fusão**: Reciprocal Rank Fusion (RRF, `score = 1/(k+rank)`, `k=60`,
  valor de referência da literatura de IR, sem tuning específico deste
  corpus pequeno). Pool de até 15 candidatos de cada busca (vetorial e
  lexical), TopK final continua 5.
- **Limitação encontrada e decisão registrada**: a função de ranking
  nativa do iFind (`%iFind.Rank`) não aceitou a sintaxe esperada nos
  testes ao vivo (`Field 'IDXCHUNKTEXTFIND' not found`) — em vez de
  adivinhar a sintaxe correta ou fingir uma posição de rank que não foi
  calculada, um match lexical soma um bônus fixo (equivalente a rank 1)
  na fusão. É uma simplificação honesta, não uma métrica de relevância
  lexical fina — registrado aqui para não ser confundido com um
  `%iFind.Rank` real caso alguém tente otimizar isso depois.
- **Abstenção não foi alterada**: o gate de `MinSimilarity` (seção 5)
  continua baseado *apenas* na melhor similaridade vetorial pura, nunca
  no score RRF — decisão deliberada para não invalidar a calibração já
  testada com os 2 pontos reais (0.653 relevante / 0.518 irrelevante).
- **Testes reais (10/09/2026)**:
  - "O que significa o erro #5005 no cenário de falha?" → recuperou e
    citou corretamente o chunk com `ERROR #5005`, 5 fontes, sem abstenção
    (melhor similaridade 0.677).
  - "receita de bolo de chocolate" (irrelevante) → abstenção mantida
    (melhor similaridade 0.521, abaixo do limiar) — confirma que a fusão
    híbrida não quebrou a calibração de abstenção já validada.
  - "Explique GeminiClient" → recuperou 5 fontes da Fase 3, todas acima
    do limiar. Nesse teste específico o Gemini também retornou um erro
    real de timeout (`ERROR #5922`) numa primeira tentativa — reforça a
    pendência de instabilidade/esgotamento de tier gratuito já registrada
    (ver `00_MASTER_PLAN.md` §8); na segunda tentativa funcionou
    normalmente.

## 4. Estado atual e pendências

**Concluído e testado (09/09/2026):** cliente Gemini, esquema de dados,
chunking, ingestão do corpus inicial (79 fragmentos / 5 documentos),
recuperação vetorial, geração com citação, abstenção calibrada, página de
consulta, resiliência a falha do modelo. Testes reais incluíram uma
pergunta relevante (respondida corretamente e citada), uma irrelevante
(abstenção correta) e uma indisponibilidade real da API (503, tratada sem
derrubar a página). **Busca híbrida** (lexical + vetorial) implementada e
testada em 10/09/2026 — ver seção 6.

**Pendente:**
- Comparação formal de estratégias de chunking (o critério do concurso
  pede "justificativa", que já temos por raciocínio; um teste comparativo
  A/B com outra estratégia fortaleceria a evidência).
- Conjunto de avaliação maior para calibrar `MinSimilarity` com mais
  rigor.
- Ingestão de documentação além dos próprios arquivos de fase do projeto
  (ex. documentação pública do IRIS), se fizer sentido para o vídeo/artigo.
- Decisão de provedor de IA para resolver o esgotamento do tier gratuito
  do Gemini (ver `00_MASTER_PLAN.md` §8) — reforçada pelo timeout real
  observado no teste de busca híbrida acima.

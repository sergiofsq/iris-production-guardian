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

## 4. Próximos passos desta fase

1. Cliente COS (`Guardian.RAG.GeminiClient`) encapsulando os dois
   endpoints via `%Net.HttpRequest`, lendo a chave de
   `Ens.Config.Credentials` — nenhuma chamada direta espalhada pelo
   código.
2. Modelo de dados: tabela de documentos (origem, versão, data de coleta)
   e tabela de fragmentos (`VECTOR(DOUBLE, 768)`, texto, referência ao
   documento).
3. Estratégia de chunking — a definir e justificar com um teste
   comparativo pequeno (critério do concurso).
4. Ingestão de um corpus inicial pequeno (documentação real do projeto,
   já autorizada — ex. os próprios `.md` do projeto ou documentação
   pública do IRIS).
5. Recuperação (`VECTOR_COSINE`) + geração com citação da fonte +
   abstenção quando não houver suporte.
6. Página de consulta (mesmo padrão do Monitor: HTML renderizado no COS).

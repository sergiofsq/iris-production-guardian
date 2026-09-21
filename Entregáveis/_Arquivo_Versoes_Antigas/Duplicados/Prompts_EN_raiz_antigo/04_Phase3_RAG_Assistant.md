# Fase 3 — RAG Assistant

## Prompt

```text
Decida o provedor de IA para embeddings e geração — precisa de tier
gratuito real, sem restrição de uso não-comercial, confirmada com uma
chamada real (não pela documentação sozinha) antes de escrever qualquer
classe COS. Teste ao menos: ChatGPT/Claude.ai (a assinatura de chat NÃO
dá acesso à API, são produtos separados — confirme antes de presumir),
Cohere (checar a licença do tier gratuito) e Gemini.

Com o provedor escolhido, implemente Guardian.RAG.GeminiClient
(Embed/Generate via %Net.HttpRequest puro — sem SDK, sem Python), leia a
chave sempre de Ens.Config.Credentials, nunca em código. Configure SSL de
saída (Security.SSLConfigs) usando o bundle de CA do sistema.

Defina o esquema (Guardian.RAG.Schema.Setup(), tabelas via CREATE TABLE
direto, não Property de classe persistente): Document, Chunk com coluna
VECTOR nativa do IRIS. Escolha a dimensão do embedding com justificativa
registrada (custo de VECTOR_COSINE vs. dimensão × tamanho do corpus).

Implemente ingestão com chunking (tamanho e overlap justificados),
recuperação (top-K por similaridade de cosseno), geração com prompt que
EXIGE citação de fonte, e abstenção calibrada: se a melhor similaridade
ficar abaixo de um limiar, responder "não sei" em vez de inventar — teste
o limiar com pelo menos um par de perguntas real (uma relevante, uma
irrelevante) antes de fixar o valor.

Depois: adicione busca HÍBRIDA (lexical iFind + vetorial, fundidas por
Reciprocal Rank Fusion) sem substituir a vetorial, e um conjunto de
avaliação formal para recalibrar o limiar de abstenção com mais de dois
pontos. Trate indisponibilidade real da API (erro 5xx) com uma mensagem
clara na tela, nunca travando a página nem inventando resposta.
```

## Resultado real (não o esperado — o observado)

- **Decisão de provedor com dois descartes reais**: OpenAI confirmado
  sem tier gratuito (nem embeddings nem chat) em teste ao vivo; Cohere
  descartado por restrição explícita de uso não-comercial no tier
  gratuito. **Google Gemini** escolhido, com a ressalva aceita pelo
  proprietário de que o tier gratuito permite uso do conteúdo para
  melhorar produtos — só documentação já pública foi indexada.
- **Nome de modelo desatualizado corrigido pela própria API**:
  `gemini-2.5-flash` devolveu `404` real ("no longer available to new
  users... use models/gemini-3.6-flash") — corrigido consultando o erro,
  não por suposição.
- **3 erros reais de API do IRIS corrigidos**: `%SQL.Statement` não tem
  `%GetLastIdentity()` (usar `%ROWID` do resultset do INSERT); `$Get` não
  funciona em propriedade de `%DynamicObject` (usar `.%Get("chave")`);
  falso alarme de encoding UTF-8 — o terminal de depuração corrompia a
  exibição de acentos, mas um hexdump dos bytes HTTP reais confirmou
  UTF-8 correto de ponta a ponta (registrado para não repetir a
  investigação).
- **Indisponibilidade real observada, não simulada**: a API do Gemini
  devolveu `503 UNAVAILABLE` de verdade durante os testes — motivou o
  `Try/Catch` que hoje mostra mensagem clara em vez de derrubar a página.
- Limiar de abstenção calibrado em 0.58 a partir de 2 pontos reais
  (pergunta relevante = 0.653, irrelevante = 0.518) — depois formalizado
  com um conjunto de avaliação maior (`Guardian.RAG.Eval`).
- Bônus **multimodelo** (segundo provedor, Groq) veio bem depois, ver
  `08_Bonus_Multimodel_Groq.md`.

Evidência completa e datada: `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md`.

# Bônus — Multimodelo (segundo provedor de IA real)

## Prompt

```text
Adicione acesso real a um segundo provedor de IA, gratuito e sem cartão
de crédito, para a geração do RAG Assistant — não um clone que finge usar
outro modelo. Pesquise pelo menos 3 opções reais (ex.: Groq, OpenRouter,
Cohere, Mistral) e escolha considerando: tier gratuito sem cartão,
simplicidade de integração via HTTP puro (sem SDK, sem Python), e limites
de uso.

Escopo: só a GERAÇÃO precisa trocar de provedor. Reaproveite a
recuperação/embeddings já indexados no provedor atual — reingestar o
corpus inteiro num espaço vetorial novo só para "provar multimodelo" não
tem valor real, e o segundo provedor pode nem oferecer endpoint de
embeddings (confirme antes de presumir que oferece).

1. Crie um client novo (mesmo padrão do client existente: %Net.HttpRequest
   puro, chave sempre de Ens.Config.Credentials, nunca em código) com o
   mesmo contrato de método (Generate(prompt) -> texto).
2. Torne o método de geração do RAG capaz de receber qual client usar,
   sem duplicar a lógica de recuperação/prompt/abstenção.
3. Crie uma segunda página/entrada de menu usando o client novo.
4. Teste a chamada real ANTES de fixar o nome do modelo — se a API
   devolver um erro dizendo que o modelo não existe, consulte o endpoint
   de listagem de modelos da própria API em vez de adivinhar outro nome.
5. Teste de ponta a ponta pela PÁGINA de verdade (não só o client
   isolado): investigar um componente, ir para a página do segundo
   provedor, usar a pergunta sugerida do contexto da investigação, e
   confirmar uma resposta real e citada — não uma abstenção indevida.
```

## Resultado real (não o esperado — o observado)

- Provedor escolhido: **Groq** (free tier sem cartão, API compatível com
  o formato de Chat Completions da OpenAI, limites mais folgados que as
  alternativas avaliadas). Descartados nesta rodada: Cohere (mesma
  restrição de uso não-comercial já descartada na escolha do provedor
  principal), OpenRouter (free tier mais apertado), Mistral (rate limit
  de experimentação mais baixo).
- **Confirmado, não presumido**: Groq **não tem endpoint de embeddings**
  no free tier (só chat/geração, um modelo de transcrição e alguns
  modelos de guarda) — checado contra `/openai/v1/models` com a chave
  real antes de decidir a arquitetura. Reforça que reaproveitar os
  embeddings do provedor principal era a decisão certa, não um atalho.
- `Guardian.RAG.Query.Ask` ganhou um parâmetro `pGenerationClient`
  (default o client original) em vez de duplicar toda a lógica de
  recuperação/prompt/abstenção na página nova.
- **Nome de modelo errado na primeira tentativa, corrigido pela própria
  API**: um modelo Llama de uso geral que existia no conhecimento do
  agente devolveu `404` real ("does not exist or you do not have access
  to it") — o catálogo do Groq tinha mudado. Corrigido consultando
  `/openai/v1/models` com a chave real e escolhendo um modelo de fato
  disponível no momento do teste.
- Testado de ponta a ponta pela página real (não só o client isolado):
  login → Investigator → RAG Assistant do segundo provedor → pergunta
  sugerida do contexto da investigação → resposta real, citada, com
  passos acionáveis — confirmando que não é um clone que finge usar outro
  modelo.
- Renomeado o rótulo do menu do placeholder genérico "novo modelo" para o
  nome real do provedor assim que a escolha foi confirmada — incluindo o
  `<title>` da página, que estava com o texto hardcoded (não
  internacionalizado), fácil de esquecer numa renomeação como essa.

Evidência completa e datada:
`docs/planejamento/04_FASE_3_RAG_ASSISTANT.md` §3.1.1.

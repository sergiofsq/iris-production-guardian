# Fase 5b — Overhaul da UX de carregamento e cobertura completa de i18n

Trabalho pós-hardening (17/09/2026), fechado a partir de uma lista de
observações reais do proprietário usando a aplicação (`Ajustes.txt`,
itens 1 a 4) — não hipotético. Os 4 prompts abaixo são reproduzidos
**literalmente**, na ordem em que o proprietário escreveu (mesmo padrão
do prompt real da Fase 0).

## Prompt 1 — Loader ausente nos botões de ação

```text
sempre que houver um botão e houver algum processamento ou pesquisa, deve
aparecer carregar o Loader. Por exemplo, na pagina do RAG Groq o botão Ask
quando clicado, não sinaliza ao usuário este processamento. Isso acontece
também na página Investigator. Revise toda a aplicação
```

### Resultado real (não o esperado — o observado)

Causa raiz real, não cosmética: a mutação que desabilitava o botão e
revelava o overlay acontecia no mesmo tick de evento em que o navegador
já começava a navegar para a próxima página — o motor de renderização
nunca chegava a pintar o overlay antes do documento antigo ser destruído.
Corrigido com um par de funções compartilhadas
(`Guardian.UI.Shared.RenderLoadingScript` / `RenderLoadingOverlay`)
reaproveitadas pelas 3 páginas de ação (RAG Gemini, RAG Groq,
Investigator).

## Prompt 2 — Cobertura de idioma incompleta

```text
O sistema tem que obedecer as opções de linguagem do usuário, então, se
estiver selecionado PT, tudo deve estar em portugues. Revise toda a
aplicação nas 2 linguagens.
```

### Resultado real

Textos com `<title>`/`<h1>` hardcoded (fora de `I18n.T()`) sobreviveram a
revisões anteriores em três páginas — Monitor, Investigator e RAG
(Gemini). Ligados ao dicionário de tradução; chaves novas
`monitor.h1`/`investigator.h1` adicionadas ao `Guardian.UI.I18n`.

## Prompt 3 — Redesenho visual do indicador de ocupado

```text
Vamos mudar o layout do sinal de ocupado. Na pasta Imagens/Config existe
um arquivo de nome LoaderRosa.jpg. Voce precisa criar um, nos tons de
cores da nossa aplicação para susbstituir o loader atual que temos. Ele
vai aparecer no meio da tela, sobrepondo a aplicação, que ficará em um
tom escuro para mostrar inatividade. Esse coportamento lembra muito uma
abertura de modal. Este ícone do loader deve ser animado, rodando. Retire
o fundo branco para dar mais realismo.
```

### Resultado real

Overlay modal de tela cheia, fundo escuro semi-transparente, com um
spinner radial animado em **CSS puro** (sem nenhum asset de imagem —
menos peso, escala perfeita em qualquer resolução) na paleta teal da
aplicação, inspirado no estilo de referência de
`Imagens/Config/LoaderRosa.jpg` mas sem fundo branco.

## Prompt 4 — Logo ao lado do loader

```text
O Loader ficou ótimo, mas gostaria que ao lado do loader aparecesse a
logo do PRODUCTION GUARDIAN.. de forma elegante.
```

### Resultado real

Badge da logo, sensível a tema claro/escuro (reaproveitando o mesmo
padrão já usado na barra lateral), posicionado ao lado do spinner dentro
do overlay.

## Dois bugs reais encontrados testando ao vivo (mesma sessão, depois dos 4 prompts acima)

Não fizeram parte de nenhum prompt — foram encontrados pelo proprietário
testando o resultado na tela, e corrigidos na hora:

- **O loader aparecia e sumia rápido demais.** Causa raiz confirmada
  deterministicamente (segurando uma resposta do servidor aberta de
  propósito por 2-4s e observando o overlay desaparecer quase
  imediatamente mesmo assim): `form.submit()` destrói o contexto JS do
  documento antigo **~100-200ms depois de ser chamado**, não quando a
  resposta do servidor chega. Corrigido substituindo a navegação real por
  `fetch()` + `document.open()/write()/close()`, trocando o HTML no mesmo
  documento em vez de navegar — o overlay não é destruído até a resposta
  estar pronta de verdade.
- **A logo apareceu gigante/cortada.** Causa raiz: **cache de CSS do
  navegador**, não bug de código —
  `iris-guardian-theme.css?v=2` nunca tinha sido incrementado apesar do
  CSS ter sido reescrito várias vezes nesta mesma sessão, então o
  navegador continuava servindo uma cópia antiga sem as regras de
  tamanho do novo badge da logo (imagens renderizando no tamanho nativo,
  1983x793px). Corrigido incrementando para `?v=3` nas 4 páginas.
  **Lição aplicada:** sempre incrementar o `?v=` de
  `iris-guardian-theme.css` na mesma edição que muda seu conteúdo.

## Ajuste adicional, mesma sessão (não pedido em prompt, feito por consistência)

A lista de hosts da barra lateral do Production Monitor foi reordenada de
alfabética para a ordem lógica do fluxo — **Service → Process →
Operation** (`Guardian.Monitor.StatusCollector`) — para bater com o
diagrama de arquitetura mostrado no roteiro de gravação e no manual.

Evidência completa e datada: commit `c12339f` (17/09/2026) e
`Ajustes.txt` (itens 1 a 4, marcados `FEITO`).

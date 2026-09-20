# Redesenho de UI — barra lateral persistente com saúde da Production sempre visível

Aplica-se depois que Monitor (Fase 2), Investigator (Fase 4) e o primeiro
RAG Assistant (Fase 3) já existiam como páginas completas e independentes.
Sem este passo, um agente reproduziria três páginas que se substituem
inteiramente ao navegar — não a UI real de hoje, onde a saúde da
Production fica visível o tempo todo.

## Prompt

```text
As páginas de Monitor, Investigator e RAG Assistant hoje têm cada uma seu
próprio cabeçalho/navegação no topo, e navegar de uma para outra substitui
a página inteira — perde-se de vista o estado de saúde da Production ao
sair do Monitor. Redesenhe para uma barra lateral esquerda PERSISTENTE,
compartilhada pelas três páginas: logo, menu de navegação, e um resumo
compacto ao vivo de cada host da Production (nome + indicador de saúde),
usando a MESMA fonte de dados já usada pela view detalhada do Monitor —
não duplique a lógica de coleta.

Sem JavaScript client-side pesado, sem iframe — mantenha a mesma filosofia
de página renderizada no servidor do resto da aplicação. Teste ao vivo
que as três páginas renderizam a barra corretamente, com o item ativo
destacado e o status real dos hosts, e que o fluxo completo do
Investigator (selecionar componente, investigar, ler resultado) continua
funcionando dentro do novo layout.
```

## Resultado real (não o esperado — o observado)

- Componente compartilhado novo, `Guardian.UI.Shared.RenderSidebar`,
  reaproveitado pelas três páginas — reusa `Guardian.Monitor.StatusCollector`
  (a mesma fonte de dados da view detalhada do Monitor) em vez de duplicar
  a lógica de coleta de saúde.
- Confirmado ao vivo: as três páginas renderizam a barra com o
  `aria-current` correto no item ativo e o status real de cada host; o
  fluxo completo do Investigator (selecionar componente → Investigate →
  ler o resultado) continua funcionando dentro do novo layout.

### Desvio experimentado e descartado na mesma sessão (documentar por transparência, não repetir)

Antes de fechar no formato acima, foi tentado abrir Investigator/RAG como
um **modal flutuante arrastável** sobre o Monitor (iframe + JS,
`?embed=1`, `iris-guardian-modal.js`). Revertido (`c737244`) por
problemas de UX sem solução simples: arrastar para fora da tela sem
como voltar; Esc não fechava porque o foco ficava dentro do iframe;
clicar no conteúdo de um modal em segundo plano não trazia ele para
frente. O resumo compacto da barra lateral já resolve o objetivo original
("não perder de vista o Monitor") sem nenhum desses problemas — não vale
reintroduzir modal/iframe/drag para esta UI.

Mantido do experimento (não relacionado ao modal em si, vale a pena):
`Guardian.UI.RAGPage` passou a mostrar a última investigação do
Investigator como contexto acima do formulário do RAG, com uma pergunta
sugerida já preenchida.

Evidência completa e datada: commits `3a850cc` e `c737244` (11/09/2026).

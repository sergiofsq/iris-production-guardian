# Fase 4 — AI Incident Investigator / IntegratedML / API

> Consolida a implementação do terceiro módulo do MVP. IntegratedML já
> está registrado como bloqueado (VR-003, `07_SCORECARD_EVIDENCIAS.md`) —
> não perseguido nesta fase. API pública fica como pendência aberta.

## 1. Escopo (contexto, seção 2)

- Receber incidente/componente + intervalo temporal; reunir métricas,
  eventos e trechos documentais autorizados.
- Produzir resumo, evidências, hipóteses, lacunas e próximos passos, com
  referências rastreáveis.
- Separar observação de hipótese: correlação não comprova causa raiz.
- Não exibir percentuais de confiança inventados.
- Somente leitura no MVP — nenhuma remediação automática.
- Persistir contexto suficiente para revisar uma investigação depois.

Aceite proposto: no cenário de falha conhecido, a resposta aponta
evidências reais e admite quando não há informação suficiente;
indisponibilidade do modelo não impede consultar as evidências.

## 2. Implementação (10/09/2026)

Três classes novas em `Guardian.Investigator.*`, mais uma página:

- **`Guardian.Investigator.Schema`** — DDL da tabela
  `Guardian_Investigator.Investigation` (Component, WindowMinutes,
  CreatedAt, EventCount, DocumentCount, ModelAvailable, Analysis) — mesmo
  padrão de `Guardian.RAG.Schema`. Esquema simplificado deliberadamente:
  não há colunas separadas de "hipóteses"/"lacunas" porque o Analyzer não
  as extrai como campos estruturados — guardar isso separado seria fingir
  um dado que não foi de fato calculado.
- **`Guardian.Investigator.EvidenceCollector`** — junta evidência real
  para um componente + janela de tempo:
  - Saúde atual: reaproveita `Guardian.Monitor.StatusCollector` (Fase 2),
    sem duplicar a lógica de healthy/degraded/unavailable/unknown.
  - Eventos reais: `Ens.MessageHeader` filtrado por
    `SourceConfigName`/`TargetConfigName` e janela de tempo, com o texto
    de erro convertido via `$System.Status.GetErrorText` — verificado ao
    vivo que transforma o valor bruto serializado do `ErrorStatus`
    (`"0  i<Ens>ErrFailureTimeout..."`) em texto legível
    (`"ERROR <Ens>ErrFailureTimeout: FailureTimeout de 15 segundos... ERROR #5005: Cannot open file..."`).
  - Documentação relevante: reaproveita `Guardian.RAG.Query.Retrieve`
    (busca híbrida da Fase 3 — ver seção 3 abaixo sobre esse refactor),
    usando o nome do componente + texto dos erros encontrados como
    consulta.
  - Falha do RAG (embeddings indisponíveis) é isolada em `Try/Catch` -
    não pode impedir a coleta de métricas/eventos, requisito explícito
    do aceite.
- **`Guardian.Investigator.Analyzer`** — monta um prompt com a evidência
  real (`BuildPrompt`) e pede ao Gemini resumo/observações/hipóteses/
  lacunas/próximos passos, com instrução explícita para não inventar
  percentual de confiança e separar observação de hipótese. Se o modelo
  falhar, a evidência coletada continua disponível (`modelAvailable = 0`,
  a página mostra a evidência normalmente) — mesmo padrão de resiliência
  já usado no RAG Assistant.
- **`Guardian.UI.InvestigatorPage`** — formulário (componente real, via
  dropdown populado por `StatusCollector`; janela em minutos), mostra
  saúde atual, lista de eventos (com erro real destacado), documentação
  citada e a análise da IA. Persiste cada investigação na tabela acima.
  Mesmo tema visual das demais páginas (`assets/css/iris-guardian-theme.css`).

## 3. Refactor no RAG: `Guardian.RAG.Query.Retrieve`

`Guardian.RAG.Query.Ask` fazia recuperação + geração numa única chamada.
Para o Investigator reaproveitar a busca híbrida sem disparar uma geração
de texto desnecessária (a geração final é feita uma única vez, com toda
a evidência junta, no `Analyzer`), a recuperação foi extraída para um
método próprio, `Retrieve(pQuestion)`, retornando
`{sources, bestSimilarity, contextText}`. `Ask` passou a chamar
`Retrieve` internamente e manter exatamente o mesmo comportamento público
— testado após o refactor: mesma pergunta ("erro #5005"), mesmo resultado
(`abstained=0`, similaridade 0.677, 5 fontes) de antes do refactor.

## 4. Bugs reais encontrados e corrigidos

1. **Cutoff de janela de tempo com `<ILLEGAL VALUE>`**: a primeira versão
   de `EvidenceCollector` calculava o corte de data tratando só rollover
   de exatamente 1 dia (`Set tSecs = tSecs + 86400`), suficiente para o
   `ErrorWindowSeconds` fixo do Monitor (900s) mas não para uma janela
   configurável pelo usuário — uma janela de vários dias gerava um valor
   de segundos ainda negativo depois do ajuste único, e `$ZDATETIME`
   rejeitava com `<ILLEGAL VALUE>`. Corrigido decompondo a janela inteira
   em dias + segundos antes de subtrair.
2. **`ErrorStatus` bruto não é texto legível**: `Ens.MessageHeader.ErrorStatus`
   guarda um `%Status` serializado (mistura de caracteres de controle e
   texto, ex. `"0  i<Ens>ErrFailureTimeoutPERROR #5005..."`) — não dá pra
   mostrar direto ao usuário nem passar pro prompt da IA sem tratar.
   Resolvido com `$System.Status.GetErrorText()`, confirmado ao vivo
   contra mensagens reais de erro do experimento de falha/recuperação da
   Fase 1.

## 5. Achado registrado, não corrigido nesta fase

Colunas `TIMESTAMP` (`CreatedAt` em `Guardian_Investigator.Investigation`
e também em `Guardian_RAG.Document`/`Chunk`, já em produção desde a Fase 3)
retornam um número grande sem sentido (ex. `1154710572020846976`) quando
lidas via `%SQL.Statement` + `%Get`/`%Display`, em vez de uma data
legível. Não é regressão desta fase — confirmado que a tabela do RAG já
tinha exatamente o mesmo comportamento. Não afeta nada exibido hoje (nenhuma
página mostra esse campo), então não foi corrigido agora — registrado
para não ser confundido com um bug novo se alguém notar depois.

## 6. Teste real (10/09/2026)

Investigação de `Guardian.Operation.FileOutputOperation` contra o
histórico real do experimento de falha/recuperação da Fase 1 (janela
grande o suficiente para cobrir os dados de 09/09/2026):

- 20 eventos reais recuperados, incluindo os 3 episódios de falha
  (`INC-003`, `INC-003b`, `INC-MONITOR`) com o erro `#5005` correto.
- Saúde atual reportada como `unavailable` (dado real da Production
  parada no momento do teste, não fabricado).
- Análise gerada corretamente separou OBSERVAÇÕES (contagem de falhas,
  horários, recuperações) de HIPÓTESES (possíveis causas), sem nenhum
  percentual de confiança inventado, e identificou como LACUNA legítima
  a discrepância entre `unavailable` e `erros recentes=0` — um achado
  real que a própria análise sinalizou corretamente como incerteza, não
  como fato.
- Investigação persistida em `Guardian_Investigator.Investigation`
  (confirmado por SQL).

## 7. Pendente

- IntegratedML: bloqueado (VR-003), fora do escopo do MVP.
- API pública adequada (bônus): não iniciada.
- Conjunto de teste maior para o Investigator (mais componentes, mais
  cenários de falha) — só o `FileOutputOperation` foi testado até aqui.

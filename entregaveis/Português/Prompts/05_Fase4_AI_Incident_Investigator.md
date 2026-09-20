# Fase 4 — AI Incident Investigator

## Prompt

```text
Implemente o AI Incident Investigator: dado um componente real da
Production (escolhido de uma lista vinda do mesmo StatusCollector do
Monitor — nunca texto livre) e uma janela de tempo, produza um resumo com
hipóteses separadas de observação, sem inventar percentual de confiança.

1. Guardian.Investigator.EvidenceCollector — junta evidência REAL: saúde
   atual do componente (reaproveita StatusCollector), eventos da janela
   (Ens.MessageHeader, com erro real destacado via
   $System.Status.GetErrorText, não o %Status bruto), e os documentos
   mais relevantes do RAG sobre esse componente (reaproveita
   Guardian.RAG.Query.Retrieve — refatore para expor recuperação pura,
   sem geração, se ainda não existir).
2. Guardian.Investigator.Analyzer — monta um prompt estruturado a partir
   dessa evidência real e pede ao modelo de IA: resumo, observações,
   hipóteses (explicitamente separadas de fato observado), lacunas de
   evidência, próximos passos sugeridos. Nunca inventar eventos ou um
   percentual de confiança que a evidência não sustenta.
3. Guardian.UI.InvestigatorPage — formulário com o componente real e a
   janela, mostrando saúde atual, lista de eventos, a análise da IA, e a
   documentação usada como contexto.
4. Persista cada investigação (componente, janela, análise) para poder
   revisá-la depois e para alimentar o RAG Assistant com o contexto da
   última investigação.

Teste contra o histórico real do experimento de falha/recuperação da
Fase 1 — a janela precisa cobrir o incidente de verdade, e a análise
precisa citar a métrica real (não um valor redondo suspeito).
```

## Resultado real (não o esperado — o observado)

- **Bug real de cálculo de data**: a primeira versão do cálculo de corte
  de janela só tratava rollover de exatamente 1 dia
  (`tSecs + 86400`), suficiente para a janela fixa do Monitor mas não
  para uma janela configurável de vários dias — gerava um valor ainda
  negativo e `$ZDATETIME` rejeitava com `<ILLEGAL VALUE>`. Corrigido
  decompondo a janela inteira em dias + segundos antes de subtrair.
- **`Ens.MessageHeader.ErrorStatus` bruto não é texto legível** — é um
  `%Status` serializado com caracteres de controle misturados ao texto,
  inutilizável direto na tela ou no prompt da IA. Resolvido com
  `$System.Status.GetErrorText()`, confirmado contra mensagens reais do
  experimento de falha da Fase 1.
- **Achado registrado, não escondido nem corrigido por não afetar nada
  visível**: colunas `TIMESTAMP` devolvem um número grande sem sentido
  quando lidas via `%SQL.Statement`/`%Get` em vez de `CAST(... AS
  VARCHAR)` — já existia desde a Fase 3 (RAG), confirmado que não é
  regressão desta fase. Registrado para não ser confundido com bug novo.
- Testado contra 3 componentes reais, incluindo um `503` real do Gemini
  durante o teste (não simulado) — o Investigator reportou a
  indisponibilidade real em vez de travar ou inventar análise.
- IntegratedML permanece confirmado **indisponível** (pacote proprietário
  ausente da imagem) — não faz parte desta fase, bloqueio de Fase 0
  mantido, não contornado.

Evidência completa e datada:
`docs/planejamento/05_FASE_4_AI_INVESTIGATOR_INTEGRATEDML_API.md`.

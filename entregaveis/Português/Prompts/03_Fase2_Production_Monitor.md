# Fase 2 — Production Monitor

## Prompt

```text
Com a Production da Fase 1 rodando, construa o Production Monitor: uma
página web que mostra o estado real dos hosts da GuardianProduction
(Services, Processes, Operations) — saudável, degradado, indisponível,
desconhecido — sem nenhum número inventado.

1. Guardian.Monitor.StatusCollector — coleta, por host: se está habilitado
   e a Production/host de fato rodando (##class(Ens.Director) — não
   comparação de texto de status, ver atrito real abaixo), contagem de
   fila, contagem de mensagens, contagem de erros recentes (janela de
   tempo configurável). Fonte de dado: classes Ens.* reais, nunca valor
   fixo/simulado.
2. Guardian.API.MonitorAPI — endpoint que devolve esse estado como JSON.
3. Guardian.UI.MonitorPage — página %CSP.Page (HTML simples, sem
   framework JS) que renderiza os cartões de cada host, cores por estado,
   e persiste uma amostra da série temporal a cada carregamento (para dar
   um histórico mínimo sem precisar de um scheduler dedicado nesta v1).
4. Adicione detecção de "host travado": fila positiva e sem esvaziar nas
   últimas N amostras persistidas — teste com pelo menos um cenário real
   controlado (não um número fabricado) antes de declarar que funciona.

Regras de estado (documentar explicitamente, não deixar implícito no
código): unavailable = host desabilitado ou Production parada; healthy =
sem fila pendente e sem erro recente; degraded = fila pendente ou erro
nos últimos N segundos; unknown = nenhuma mensagem registrada ainda para
esse host. Teste a página tanto via curl quanto num navegador de verdade
antes de declarar concluído — um pode esconder bug que o outro revela.
```

## Resultado real (não o esperado — o observado)

- **Erro real de compilação**: um `Parameter ERROR_WINDOW_SECONDS = 900`
  referenciado como `..#ERROR_WINDOW_SECONDS` quebrava o parser com
  `ERROR #5559` (mensagem genérica, sem apontar a linha certa) — causa
  raiz isolada por bissecção: `_` é o operador de concatenação do COS, e
  `..#NOME_RESTO` é lido como `(..#NOME)_(RESTO)`, não um identificador
  único. Corrigido renomeando o parâmetro para PascalCase sem underscore
  (`ErrorWindowSeconds`). Não havia documentação explícita disso antes de
  testar — conhecimento verificado empiricamente.
- **Bug real, achado só pelo proprietário testando no navegador** (não
  pelos testes via curl): todos os hosts apareciam `unavailable` mesmo
  com a Production rodando normalmente — só em pt-BR. Causa: a regra
  comparava `$List(tProdEntry,1) = "Running"` (texto), mas esse texto é
  **localizado pelo idioma do navegador** (`Accept-Language: pt-BR` faz o
  IRIS devolver "Em execução"). Corrigido trocando para
  `##class(Ens.Director).IsProductionRunning()`, que devolve um
  `%Boolean` real, não texto. Prova de que testar só via curl (sem header
  de idioma) escondia o bug.
- Série temporal: bug real na ordenação (usava ID em vez de
  `CollectedAt` — mesma coisa na maioria dos casos, mas não sempre)
  corrigido depois de observado ao vivo.

Evidência completa e datada:
`docs/planejamento/03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md`.

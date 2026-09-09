# Fase 2 — Production Monitor

> Nome do arquivo preservado do histórico (`..._WSGI_TELEMETRY.md`). WSGI
> não é usado (decisão registrada em `01_FASE_0_SETUP_ARQUITETURA.md` §6,
> item 3 — conflito com premissa COS-first). Telemetria aqui significa: o
> estado real da Production, obtido por consulta direta às classes `Ens.*`
> do próprio IRIS, sem coletor externo.

## 1. Objetivo desta fase

Expor, através de uma interface própria (fora do Management Portal), o
estado real dos hosts de uma Production IRIS: saudável, degradado,
indisponível ou desconhecido — com regras documentadas, não inventadas —
e permitir rastrear uma falha até o evento original (`Ens.MessageHeader`).

## 2. Fontes de dado verificadas (nenhuma suposta)

| Dado | Fonte real confirmada |
|---|---|
| Lista de hosts da Production, tipo, habilitado/desabilitado | `Ens_Config.Item` + `Ens_Config.Production` (join por `Item.Production = Prod.ID`) |
| Tipo do host (Service/Process/Operation) | `##class(<ClassName>).%IsA("Ens.BusinessService"/"Ens.BusinessProcess"/"Ens.BusinessOperation")` — não presumido pelo nome da classe |
| Fila pendente por host | `##class(Ens.Queue).GetCount(pQueueName)` |
| Estado da Production (rodando/parada) | `##class(Ens.Director).GetProductionSummary(.info)` |
| Histórico de mensagens, origem/destino, erro | `Ens.MessageHeader` (`SourceConfigName`, `TargetConfigName`, `TimeCreated`, `ErrorStatus`) |
| Detecção de erro por linha | `ErrorStatus <> 1` — testado contra dados reais (2 erros reais do experimento de falha, seção 07 do scorecard, foram corretamente contados) |

**Limitação conhecida (`VERIFY_REQUIRED`):** nenhuma das fontes acima
detecta diretamente um job de host travado/morto que não gerou nenhuma
mensagem de erro (ex.: processo em loop infinito sem lançar exceção). A
Fase 2 v1 infere saúde a partir do tráfego de mensagens e da fila, não do
processo do sistema operacional. Registrar como limitação explícita na
interface, não esconder.

## 3. Regras de estado (documentadas)

Calculadas por host, nesta ordem:

1. **Indisponível** — a Production não está rodando (`GetProductionSummary`
   ≠ `"Running"`) **ou** o host está com `Enabled=0` em `Ens_Config.Item`.
2. **Desconhecido** — host habilitado, Production rodando, mas o host
   **nunca** apareceu em `Ens.MessageHeader` (nem como origem nem como
   destino) desde que a Production existe. Sem histórico, não há base para
   dizer que está saudável — "ausência de dados não equivale a saúde"
   (contexto, seção 2).
3. **Degradado** — host habilitado, Production rodando, com histórico, e
   pelo menos uma das condições: (a) fila pendente (`Ens.Queue.GetCount`)
   maior que zero; (b) pelo menos um erro (`ErrorStatus <> 1`) nos últimos
   15 minutos envolvendo esse host.
4. **Saudável** — habilitado, Production rodando, com histórico, sem fila
   pendente e sem erro nos últimos 15 minutos.

Janela de 15 minutos escolhida por ser o mesmo valor do `FailureTimeout`
padrão observado em `Ens.BusinessOperation` (Fase 1) — não é um valor
arbitrário sem relação com o sistema real.

## 4. O que foi implementado

- `Guardian.Monitor.StatusCollector` — lógica única de coleta e das regras
  de saúde (seção 3), chamada diretamente em COS por qualquer consumidor.
  Extraída para uma classe própria depois que a primeira versão (regras
  direto na classe REST) revelou que reaproveitar a mesma lógica na página
  HTML sem duplicar código era mais simples assim.
- `Guardian.API.MonitorAPI` (`%CSP.REST`) — endpoint `GET /status` no
  namespace `GUARDIAN`, aplicação web `/api/guardian` (senha, sem acesso
  anônimo — mesmo padrão do `/api/atelier` já usado no projeto). Chama o
  `StatusCollector` e escreve o JSON.
- `Guardian.UI.MonitorPage` (`%CSP.Page`) — página em `/csp/guardian/
  Guardian.UI.MonitorPage.cls` (aplicação web padrão do namespace).
  Chama o `StatusCollector` **diretamente em COS** (sem round-trip HTTP
  via JavaScript — evita duplicar autenticação entre app REST e app CSP)
  e renderiza os três grupos de host com cor por estado. Atualização via
  `<meta http-equiv="refresh">` a cada 10s — nenhuma lógica de negócio no
  navegador, só HTML/CSS estático gerado no servidor.

### Comando de setup da aplicação REST (reproduzível)

```objectscript
Set props("NameSpace")="GUARDIAN"
Set props("DispatchClass")="Guardian.API.MonitorAPI"
Set props("Description")="IRIS Production Guardian - Monitor REST API"
Set props("AutheEnabled")=32
Set props("Enabled")=1
Set props("IsNameSpaceDefault")=0
Do ##class(Security.Applications).Create("/api/guardian",.props)
```
(executar no namespace `%SYS`, uma única vez)

## 4.1 Erro real encontrado e corrigido durante o desenvolvimento

Ao compilar `Guardian.API.MonitorAPI` com um `Parameter ERROR_WINDOW_SECONDS
= 900;` referenciado como `..#ERROR_WINDOW_SECONDS`, o compilador recusou
com `ERROR #5559` (erro de parse genérico, sem apontar a linha certa).
Isolado por bissecção (foram necessárias várias classes de teste mínimas)
até confirmar: **nomes de `Parameter` com underscore quebram o parser
quando referenciados via `..#NOME`** — o `_` é o operador de concatenação
do ObjectScript, e a referência `..#NOME_RESTO` é lida como `(..#NOME)_
(RESTO)` em vez de um único identificador. Corrigido renomeando para
`ErrorWindowSeconds` (PascalCase, sem underscore). Não encontrei essa
informação documentada explicitamente antes de testar — registrado aqui
como conhecimento verificado empiricamente, útil para o artigo da
metodologia de IA (exemplo real de erro e correção).

## 5. Teste real (09/09/2026) — evidência, não simulação

Com o Monitor no ar, reproduzido o Experimento 1
(`docs/experiments/01_falha_recuperacao_producao.md`) enquanto consultava
o Monitor no meio do processo:

| Momento | `GET /api/guardian/status` |
|---|---|
| Antes da falha | todos os hosts `healthy` |
| ~20s após quebrar o destino e disparar um incidente | `Guardian.Operation.FileOutputOperation` e `Guardian.Process.IncidentRouterProcess` (os dois lados da mensagem com erro) mudam para `degraded`, `recentErrorCount: 1`. `Guardian.Service.FileIncidentService` (não envolvido nesse erro) continua `healthy` |
| Destino corrigido + mensagem nova enviada com sucesso | hosts **continuam `degraded`** por um tempo — comportamento esperado, não bug: a janela de erro recente é de 15 minutos, então "degraded" significa "houve um erro nos últimos 15 min", não "há um erro agora". A fila (`queueCount`) já volta a `0` imediatamente, que é o sinal de que o tráfego atual está fluindo |

Isso confirma o "Aceite proposto" do Monitor (contexto, seção 2): a falha
altera os indicadores de forma rastreável, e a saúde não é escondida nem
mostrada como recuperada instantaneamente sem base real.

## 6. Limitações explícitas desta v1 (não escondidas)

- **Sem série temporal persistida.** O cálculo é feito sob demanda a cada
  requisição (pull), não há um coletor agendado gravando amostras ao longo
  do tempo. "Horário da última coleta" = horário da requisição atual. Uma
  série temporal real (gráfico de tendência) fica para um incremento
  futuro, se houver tempo.
- **Detecção de host travado** não coberta (ver seção 2) — a saúde é
  inferida do tráfego de mensagens, não do processo do sistema
  operacional.
- **"Degraded" persiste por até 15 minutos após um erro já resolvido**
  (janela documentada na seção 3/5) — decisão consciente, não bug; evita
  que um problema recente pareça "resolvido" cedo demais.
- Sem autenticação de sessão de usuário final além da autenticação básica
  do IRIS já usada no restante do projeto.

## 7. Próximo passo

Testar visualmente no navegador (pedir confirmação ao proprietário com
print) e, se aprovado, decidir entre: (a) avançar para a Fase 3 (RAG
Assistant) ou (b) reforçar o Monitor com série temporal persistida antes
de seguir.

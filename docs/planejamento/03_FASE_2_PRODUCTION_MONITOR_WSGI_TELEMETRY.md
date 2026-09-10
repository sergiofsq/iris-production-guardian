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

## 4.2 Segundo erro real: estado da Production localizado por idioma

Confirmado visualmente pelo proprietário (print em
`Imagens/Aplicacao/MonitroPage1.jpg`): ao abrir a página no navegador
(que envia `Accept-Language: pt-BR`), **todos os hosts apareciam como
`unavailable`**, mesmo com a Production rodando e mensagens fluindo
normalmente.

Causa raiz: a regra usava `$List(tProdEntry,1) = "Running"` (comparação
de string) a partir de `Ens.Director.GetProductionSummary`. Esse texto é
**localizado pelo IRIS conforme o idioma do navegador** — em pt-BR vem
`"Em execução"`, não `"Running"` — então a comparação sempre falhava fora
do inglês. Via curl (sem header de idioma) o bug não aparecia, por isso
não foi pego nos testes anteriores.

Corrigido usando `##class(Ens.Director).IsProductionRunning(.pName)` —
retorna um `%Boolean` real (não texto) e devolve por parâmetro de saída o
nome da production efetivamente rodando; comparamos esse nome com o
esperado (`..#Production`) para não presumir que só existe uma production
possível no namespace. `tProdState` continua guardado só para exibição na
tela (o texto localizado é uma informação útil para o usuário, só não
pode ser usado na decisão de saúde). Validado testando o mesmo request
com `Accept-Language: pt-BR` via curl antes e depois da correção.

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

- **"Degraded" persiste por até 15 minutos após um erro já resolvido**
  (janela documentada na seção 3/5) — decisão consciente, não bug; evita
  que um problema recente pareça "resolvido" cedo demais.
- Sem autenticação de sessão de usuário final além da autenticação básica
  do IRIS já usada no restante do projeto.
- Sem coletor agendado independente (ver seção 6.1) — a série temporal só
  cresce quando alguém carrega a página ou chama a API.

## 6.1 Série temporal persistida + detecção de host travado (10/09/2026)

Reforço pós-Fase 4: as duas limitações da seção 6 original ("sem série
temporal", "detecção de host travado não coberta") foram fechadas.

- **`Guardian.Monitor.Schema`** — DDL de `Guardian_Monitor.HealthSample`
  (Component, Health, QueueCount, MessageCount, RecentErrorCount,
  CollectedAt), mesmo padrão das demais tabelas do projeto.
- **`Guardian.Monitor.StatusCollector.Collect`** agora grava uma amostra
  por host a cada chamada — ou seja, toda vez que a página do Monitor é
  carregada (atualiza sozinha a cada 10s) ou a API REST é chamada, uma
  amostra real é persistida. Não há coletor agendado (`Task Scheduler`)
  independente nesta v1 — a série cresce por uso real da aplicação, não
  por um cron simulado.
- **`Guardian.Monitor.StatusCollector.IsStuck(component)`** — um host é
  "travado" se as últimas 3 amostras persistidas têm fila positiva e
  não-decrescente ao longo do tempo (a fila não está esvaziando).
  Insuficiência de histórico (< 3 amostras) retorna falso, não presume
  travamento sem dado real. Testado com 4 cenários de dados controlados:
  fila crescendo 3/5/7 (travado = verdadeiro), fila esvaziando 7/3/0
  (travado = falso), sem histórico (falso), só 2 amostras mesmo
  crescendo (falso, dado insuficiente).
- **`Guardian.Monitor.StatusCollector.RecentSamples`** — últimas N
  amostras de um componente, em ordem cronológica, usada pela página para
  exibir a tendência da fila.
- **`Guardian.UI.MonitorPage`** — cada card agora mostra um selo
  "travado" quando aplicável e uma linha de tendência com os últimos
  valores de fila.
- **Bug real encontrado e corrigido**: a primeira versão ordenava as
  amostras por `CollectedAt DESC`, mas `$ZDATETIME($Horolog,3)` só tem
  granularidade de 1 segundo — amostras inseridas na mesma janela de 1s
  (reproduzido testando com inserts em sequência rápida) empatavam e
  saíam fora de ordem, quebrando a detecção. Corrigido ordenando por `ID`
  (ordem real de inserção) em vez de `CollectedAt`.
- **Achado real, não escondido**: tentei reproduzir "travado" ao vivo
  reusando o experimento de falha da Fase 1 (permissão negada no
  destino) — não funcionou como esperado. Esse tipo de falha (escrita
  recusada pelo SO) gera um erro rápido depois do `FailureTimeout` de 15s,
  não um acúmulo de fila sustentado; `Ens.Queue.GetCount` não mostra a
  mensagem "presa" durante a tentativa/retry. Ou seja, a detecção de
  "travado" cobre um modo de falha **diferente** do já demonstrado
  (backlog de fila real, ex. um host desabilitado ou destino lento sem
  timeout) — validado com dados controlados (acima), não com uma
  reprodução ao vivo desse modo de falha específico, que fica como
  trabalho futuro se fizer sentido para o vídeo.

## 7. Validação visual (09/09/2026) — confirmada

Print `Imagens/Aplicacao/MonitroPage2.jpg`: após a correção da seção 4.2,
`Guardian.Service.FileIncidentService` aparece **HEALTHY** (verde) e
`Guardian.Process.IncidentRouterProcess`/`Guardian.Operation.FileOutputOperation`
aparecem **DEGRADED** (âmbar) — exatamente o estado esperado, ainda dentro
da janela de 15 min do erro de teste da seção 5. Aprovado pelo
proprietário.

**Estado da Fase 2: concluída, incluindo o reforço de série temporal e
detecção de host travado (seção 6.1, 10/09/2026).**

## 8. Próximo passo

Fase 3 — RAG Assistant. Antes de implementar: decisão do proprietário
sobre provedor/modelo de IA para embeddings e geração (pendência já
registrada em `00_MASTER_PLAN.md` §5 e no contexto, seção 4) — Vector
Search nativo do IRIS já confirmado disponível (VR-001), falta escolher
o que gera os vetores e a resposta.

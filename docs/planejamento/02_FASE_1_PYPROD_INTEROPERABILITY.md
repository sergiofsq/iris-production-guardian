# Fase 1 — Production COS / Interoperabilidade

> Nome do arquivo preservado do histórico (`02_FASE_1_PYPROD_INTEROPERABILITY.md`),
> mas o conteúdo prioriza Production em COS, conforme a premissa obrigatória
> (contexto, seção 1.1). PyProd não foi implementado nem reivindicado — ver
> `01_FASE_0_SETUP_ARQUITETURA.md` §6, item 3.

## 1. Objetivo desta fase

Provar o trajeto de uma mensagem real pelos três tipos de host de uma
Production IRIS (Service → Process → Operation), usando um adaptador
suportado nativamente, sem dependência externa ao IRIS. Este é o pré-requisito
de infraestrutura para o Production Monitor (Fase 2).

## 2. O que foi implementado

Código-fonte em `src/Guardian/` (editado via VS Code + extensão InterSystems
ObjectScript, conectado ao namespace `GUARDIAN` do container `iris-guardian`,
compilação automática ao salvar):

| Classe | Papel | Adaptador |
|---|---|---|
| `Guardian.Messages.IncidentEvent` | Mensagem (`Ens.Request`) com dados de um incidente sintético | — |
| `Guardian.Service.FileIncidentService` | Business Service — lê arquivos `.txt` (um incidente por linha, campos separados por `\|`) | `EnsLib.File.InboundAdapter` |
| `Guardian.Process.IncidentRouterProcess` | Business Process (código, não BPL) — preenche `ProcessedBy`/`ProcessedAt` e roteia para a Operation | — |
| `Guardian.Operation.FileOutputOperation` | Business Operation — grava o incidente processado como arquivo de saída | `EnsLib.File.OutboundAdapter` |
| `Guardian.Production.GuardianProduction` | Production que conecta os três hosts acima | — |

Diretórios de dados (dentro do volume durável, sobrevivem a `docker rm`):
`/durable/guardian/in` (entrada), `/durable/guardian/archive` (arquivos
processados), `/durable/guardian/out` (saída — "destino de demonstração
controlado" citado no MVP).

Business Rules **não foram usadas aqui** — o roteamento é código simples no
Process. O motor de Business Rules (`Ens.Rule.Definition`) é um bônus
separado (+2), ainda não implementado.

## 3. Teste executado (09/09/2026) — evidência real, não simulada

1. Production iniciada: `##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")` → `%Status` OK, estado confirmado "running" via `Ens.Director.GetProductionStatus`.
2. Arquivo depositado em `/durable/guardian/in/demo1.txt`:
   ```
   INC-001|IRIS.Service.OrderIngest|HIGH|Fila de mensagens acima do limite configurado
   ```
3. Após o intervalo de polling do adaptador (5s), o arquivo:
   - desapareceu de `in/`;
   - apareceu arquivado em `archive/demo1.txt_2026-09-09_17.28.15.298`;
   - gerou `out/incident_INC-001.txt` com o conteúdo:
     ```
     INC-001|IRIS.Service.OrderIngest|HIGH|Fila de mensagens acima do limite configurado|2026-09-09 17:28:15|Guardian.Process.IncidentRouterProcess|2026-09-09 17:28:15
     ```
     Os dois últimos campos (`ProcessedBy`, `ProcessedAt`) só existem porque o
     Process de fato executou — não é um pass-through vazio.
4. Rastro em `Ens.MessageHeader` (consulta SQL real, não inferida):

   | ID | Source → Target | Status |
   |---|---|---|
   | 2 | `Guardian.Service.FileIncidentService` → `Guardian.Process.IncidentRouterProcess` | 9 (completo) |
   | 3 | `Guardian.Process.IncidentRouterProcess` → `Guardian.Operation.FileOutputOperation` | 9 (completo) |
   | 4 | `Guardian.Operation.FileOutputOperation` → `Guardian.Process.IncidentRouterProcess` (resposta síncrona) | 9 (completo) |

   (ID 1, `Ens.ScheduleService` → `Ens.ScheduleHandler`, é tráfego interno da
   Production, não faz parte do fluxo funcional.)

**Conclusão: mensagem real atravessou Service → Process → Operation, com
adaptador suportado (`EnsLib.File`), evidência em arquivo e em
`Ens.MessageHeader`.** Cobre os bônus "Service, Process e Operation" (+1) e
"Adaptador em host" (+1) da matriz — ver registro em
`07_SCORECARD_EVIDENCIAS.md`.

## 4. Erro real encontrado e corrigido durante o desenvolvimento

Ao compilar `Guardian.Process.IncidentRouterProcess`, o IRIS recusou com:

```
ERROR #5478: Keyword signature error ... Method:OnRequest, keyword 'method
argument/s signature' must be '%Library.Persistent,%Library.Persistent' or
its subclass
```

Causa: o método `OnRequest` de `Ens.BusinessProcess` exige que o parâmetro de
saída (`pResponse`) seja tipado como subclasse de `%Library.Persistent`; a
primeira versão usava `%RegisteredObject`, que não é subclasse de
`%Persistent`. Corrigido trocando para `%Persistent`. Recompilado com
sucesso — confirmado via `%Dictionary.CompiledClass.%ExistsId`, não apenas
pela ausência de mensagem de erro.

## 5. Cenário de falha controlada e recuperação (09/09/2026) — evidência real

Roteiro completo e reproduzível em
`docs/experiments/01_falha_recuperacao_producao.md` (executado do zero duas
vezes nesta sessão, com resultado idêntico — não é um exemplo hipotético).

Resumo do que foi observado:

1. Destino quebrado (`chmod 555` em `/durable/guardian/out`, removendo
   escrita de `irisowner`).
2. Incidente `INC-003` disparado. Após ~15s (`FailureTimeout` padrão do
   framework, confirmado em `Ens.BusinessOperation||FailureTimeout` =
   `15`, `RetryInterval` = `5`), a Operation registra em
   `Ens.MessageHeader.ErrorStatus`:
   ```
   <Ens>ErrFailureTimeout ... ERROR #5005: Cannot open file
   '/durable/guardian/out/incident_INC-003.txt'
   ```
   Nenhum arquivo de saída é gerado — a falha é real (erro de sistema
   operacional), não fingida na interface.
3. Destino corrigido (`chmod 755`).
4. Um incidente **novo** (`INC-004`) flui automaticamente com sucesso —
   confirma recuperação automática para tráfego novo, sem reiniciar a
   Production.
5. O incidente que falhou (`INC-003`) **não** é reentregue sozinho — o
   `FailureTimeout` já tinha expirado antes do conserto, então aquela
   tentativa específica ficou marcada como falha definitiva (comportamento
   documentado do framework `Ens.BusinessOperation`, não limitação do
   código do projeto). Reenviado manualmente via
   `##class(Ens.MessageHeader).ResendMessage(<ID>)` — sucesso confirmado
   (arquivo de saída gerado).

Isso cobre diretamente o "Aceite proposto" do Production Monitor (contexto,
seção 2): falha altera indicadores rastreáveis até o evento original, e a
recuperação (automática para tráfego novo, manual para a mensagem afetada)
é visível — nada foi escondido ou fingido como sucesso.

## 6. Pendências desta fase (não feitas ainda)

- **Business Rules** (bônus +2): roteamento ainda é código fixo, não usa
  `Ens.Rule.Definition`.
- Nenhuma mensagem foi gerada com **carga real de "Production" observável
  no Monitor** ainda — isso é a Fase 2.

## 7. Próximo passo

Começar a Fase 2: coletar o estado real dos hosts/filas via classes `Ens.*`
(o que já exploramos manualmente aqui — `Ens.MessageHeader`,
`Ens_Config.Item`) para alimentar o Production Monitor.

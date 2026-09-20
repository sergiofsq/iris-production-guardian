# O que significam os números dos cards do Production Monitor

Referência: print `O que são as mensagens.jpg`, nesta mesma pasta.

Cada card representa um **host** — um componente da produção de
interoperabilidade (um Service, um Process ou uma Operation). Todos os
números vêm de uma única classe, `Guardian.Monitor.StatusCollector.cls`
(a mesma lógica é usada tanto pela página quanto pela API — não existe
cálculo duplicado ou diferente em outro lugar).

## Fila (Queue)

**Definição:** quantas mensagens estão paradas agora, esperando para
serem processadas por aquele host — a fila de entrada dele, não
processada ainda.

**Como é medida:** chamada nativa do IRIS, `Ens.Queue.GetCount(nome_do_host)`.
Não é estimativa nem cache — é a contagem real da fila naquele instante
exato da coleta.

**Por que importa:** Fila > 0 é um dos dois motivos que fazem o host
virar "degradado" (ver seção do selo de saúde, abaixo).

## Mensagens (Messages)

**Definição:** quantas mensagens, no total acumulado desde sempre (sem
filtro de tempo), aquele host já processou — seja como origem ou como
destino.

**Como é medida:** consulta SQL na tabela nativa do IRIS que guarda o
histórico de toda mensagem que passou pela produção:

```sql
SELECT COUNT(*) FROM Ens.MessageHeader
WHERE (SourceConfigName = ? OR TargetConfigName = ?)
```

(o nome do host entra nos dois `?`). É contagem acumulada — não é
"mensagens na última hora" nem "mensagens hoje".

## Erros recentes (Recent errors)

**Definição:** quantas dessas mensagens tiveram erro **e** aconteceram
nos últimos **15 minutos (900 segundos)** a partir do momento em que a
página coletou o dado.

**Como é medida:**

```sql
SELECT COUNT(*) FROM Ens.MessageHeader
WHERE (SourceConfigName = ? OR TargetConfigName = ?)
  AND ErrorStatus <> 1
  AND TimeCreated > <agora menos 15 minutos>
```

`ErrorStatus <> 1` é a convenção do IRIS para "essa mensagem teve erro"
(`1` significa sem erro). A janela de 15 minutos não foi escolhida à
toa: é o mesmo valor padrão do `FailureTimeout` do
`Ens.BusinessOperation` — ou seja, o tempo que o próprio motor do IRIS
espera antes de desistir de uma tentativa e marcar a mensagem como
falha de vez.

## Tendência de fila (10 amostras) / queue trend

**Definição:** os últimos 10 valores de "Fila" registrados para aquele
host, do mais antigo para o mais recente — uma mini-série temporal para
enxergar se a fila está subindo, descendo ou parada, sem precisar ficar
olhando a tela o tempo todo.

**Como é medida:** toda vez que a página do Monitor carrega (ou a API
`/api/guardian/status` é chamada), o valor atual de Fila/Mensagens/Erros
recentes daquele host é salvo como uma linha nova na tabela
`Guardian_Monitor.HealthSample`. A "tendência" exibida são as últimas
10 linhas dessa tabela para aquele host (`SELECT TOP 10 QueueCount ...
ORDER BY ID DESC`, depois invertida para ficar do mais antigo para o
mais recente). **Importante:** não existe um coletor rodando sozinho em
segundo plano nesta versão — a amostra só é gravada quando alguém faz a
página carregar ou chama a API (você navegando, o loop de tráfego
contínuo do roteiro de gravação, etc.).

## O selo de saúde (SAUDÁVEL / DEGRADADO / INDISPONÍVEL / DESCONHECIDO / TRAVADO)

Não foi perguntado diretamente, mas é calculado a partir dos três
números acima, então ajuda a fechar o entendimento — é literalmente a
legenda que já existe dentro da própria aplicação (botão "Legend" na
tela do Monitor):

- **saudável** — sem fila pendente (Fila = 0) e sem erro nos últimos 15
  minutos.
- **degradado** — Fila > 0 **ou** Erros recentes > 0.
- **indisponível** — o host está desabilitado na configuração, ou a
  Production inteira está parada.
- **desconhecido** — Mensagens = 0, isto é, esse host nunca processou
  nada ainda (ausência de dado não é tratada como sinônimo de saúde
  boa).
- **travado** — não aparece no print atual, mas existe como estado
  extra: quando as últimas 3 amostras persistidas de Fila são todas
  positivas e não caem (a fila não está esvaziando) — sinal de algo
  realmente travado, não só um pico passageiro que já passou.

## Lendo o print salvo nesta pasta como exemplo

No print (coletado em 18/09/2026 19:24:09):

| Host | Fila | Mensagens | Erros recentes | Selo |
|---|---|---|---|---|
| `FileIncidentService` | 0 | 3 | 0 | saudável |
| `IncidentRouterProcess` | 0 | 9 | 0 | saudável |
| `FileOutputOperation` | 0 | 4 | 0 | saudável |
| `PriorityOutputOperation` | 0 | 2 | 0 | saudável |

Todas as tendências de fila mostram só zeros porque o print foi tirado
num momento sem falha ativa — nenhuma fila chegou a se acumular nas
últimas 10 amostras persistidas.

---

Fontes no código-fonte, se quiser conferir com mais detalhe:
`src/Guardian/Monitor/StatusCollector.cls` (cálculo de cada número) e
`src/Guardian/UI/I18n.cls`, linhas 89-95 (textos exibidos e legenda
oficial em PT/EN).

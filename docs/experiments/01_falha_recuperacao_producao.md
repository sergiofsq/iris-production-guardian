# Experimento 1 — Falha e recuperação da Production (roteiro reproduzível)

> Objetivo: gerar, de forma controlada e repetível, o par
> **falha → recuperação** exigido pelo MVP (contexto, seção 2, "Aceite
> proposto" do Production Monitor) e pelo roteiro de vídeo (seção 8). Todos
> os comandos abaixo já foram executados uma vez em 09/09/2026 e o
> resultado real de cada um está registrado em
> `../planejamento/02_FASE_1_PYPROD_INTEROPERABILITY.md` §5. Este arquivo é o roteiro
> para **reproduzir** o mesmo experimento ao vivo, na hora da gravação.

## Pré-requisitos

- Container `iris-guardian` rodando (`docker start iris-guardian` se estiver
  parado).
- Production `Guardian.Production.GuardianProduction` no estado **Running**
  (confira em Interoperability → Configure → Production, ou via
  `##class(Ens.Director).GetProductionStatus(.p,.s)` no terminal — `s` deve
  ser `1`).
- Diretórios `/durable/guardian/{in,archive,out,out_priority}` vazios
  (estado limpo) — ver passo 0.

## Passo 0 — Garantir estado limpo

```sh
docker exec -i iris-guardian sh -c \
  'rm -f /durable/guardian/in/* /durable/guardian/archive/* /durable/guardian/out/* /durable/guardian/out_priority/* && \
   chmod 755 /durable/guardian/out /durable/guardian/out_priority'
```

(Opcional para a gravação: abrir a tela do **Message Viewer**
(`http://localhost:53773/csp/.../interop-editor/...` → aba "Message
Viewer") e a pasta `/durable/guardian/out` em outra janela, para mostrar
ao vivo o antes/depois.)

## Passo 1 — Fluxo saudável (baseline)

```sh
docker exec -i iris-guardian sh -c \
  'echo "INC-BASE|IRIS.Service.OrderIngest|LOW|Fluxo normal, sem falha" > /durable/guardian/in/baseline.txt && \
   chown irisowner:irisowner /durable/guardian/in/baseline.txt'
```

Aguardar ~10s (o Service verifica a pasta a cada 5s) e confirmar:

```sh
docker exec -i iris-guardian ls -la /durable/guardian/out
```

Deve aparecer `incident_INC-BASE.txt`. **Isso é o estado saudável** — mostrar
na tela antes de quebrar nada.

## Passo 2 — Quebrar o destino (falha controlada)

> **Atenção (corrigido 13/09/2026):** desde o Business Rule de roteamento
> por severidade (`Guardian.Rule.IncidentRoutingRule`, bônus fechado
> 10/09/2026, posterior à primeira versão deste roteiro), severidade
> `CRITICAL`/`HIGH`/`MEDIUM` vai para `Guardian.Operation.PriorityOutputOperation`,
> que escreve em **`/durable/guardian/out_priority`** — não mais em
> `/durable/guardian/out` (esse continua sendo só o destino de `LOW`, via
> `Guardian.Operation.FileOutputOperation`). Quebrar `/durable/guardian/out`
> com uma mensagem `CRITICAL` não causa mais falha nenhuma (confirmado ao
> vivo 13/09/2026: a mensagem é entregue normalmente em `out_priority`,
> sem erro). O passo abaixo já reflete o diretório correto.

```sh
docker exec -i iris-guardian chmod 555 /durable/guardian/out_priority
```

Isso remove a permissão de escrita do usuário `irisowner` (dono do processo
IRIS) no diretório de saída usado por incidentes `CRITICAL`/`HIGH`/`MEDIUM`
— simula um destino indisponível (disco cheio, permissão negada, share
fora do ar) sem tocar em nada dentro do IRIS.

## Passo 3 — Disparar o incidente que vai falhar

```sh
docker exec -i iris-guardian sh -c \
  'echo "INC-003|IRIS.Service.PaymentGateway|CRITICAL|Falha de escrita simulada no destino" > /durable/guardian/in/demo3.txt && \
   chown irisowner:irisowner /durable/guardian/in/demo3.txt'
```

## Passo 4 — Observar a falha (janela de ~20s)

```sh
docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
set st=##class(%SQL.Statement).%New()
set sc=st.%Prepare("SELECT ID, SourceConfigName, TargetConfigName, Status, ErrorStatus FROM Ens.MessageHeader ORDER BY ID DESC")
set rs=st.%Execute()
do rs.%Display()
halt
EOF
```

**Resultado real observado (09/09/2026, reconfirmado 13/09/2026 com o
diretório correto pós Business Rules):** depois de ~15s (o
`FailureTimeout` padrão do `Ens.BusinessOperation`), a linha da Operation
mostra `ErrorStatus`:

```
ERROR #5005: Cannot open file '/durable/guardian/out_priority/incident_INC-003.txt'
```

embrulhado em `<Ens>ErrFailureTimeout`. O arquivo **não aparece** em
`out/` — confirmar com `ls`. Na tela do Management Portal (Message
Viewer ou o host `Guardian.Operation.FileOutputOperation` na Production
Configuration), o host mostra a mensagem com erro.

Este é o momento de mostrar no vídeo: "aqui a falha é real, não simulada
na interface — o processo tentou escrever e o sistema operacional recusou."

## Passo 5 — Corrigir o destino

```sh
docker exec -i iris-guardian chmod 755 /durable/guardian/out_priority
```

## Passo 6 — Recuperação automática (mensagens novas)

```sh
docker exec -i iris-guardian sh -c \
  'echo "INC-004|IRIS.Service.PaymentGateway|LOW|Fluxo normal apos recuperacao do destino" > /durable/guardian/in/demo4.txt && \
   chown irisowner:irisowner /durable/guardian/in/demo4.txt'
```

Aguardar ~10s e conferir `ls /durable/guardian/out` — `incident_INC-004.txt`
deve aparecer. **Isso prova que o sistema se recupera sozinho para tráfego
novo**, sem reiniciar nada.

## Passo 7 — Recuperação manual da mensagem que falhou

A mensagem `INC-003` **não** é reentregue automaticamente — o
`FailureTimeout` já expirou antes do destino ser corrigido, então aquela
tentativa específica ficou definitivamente marcada como falha (isso é
comportamento real e documentado do framework, não uma limitação do nosso
código). Para reentregá-la:

1. Descobrir o `ID` da mensagem Process→Operation que falhou (na consulta
   do passo 4, é a linha com `SourceConfigName =
   Guardian.Process.IncidentRouterProcess` e `TargetConfigName =
   Guardian.Operation.FileOutputOperation` referente ao `INC-003`).
2. Reenviar:
   ```sh
   docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
   set sc=##class(Ens.MessageHeader).ResendMessage(<ID_DA_MENSAGEM>)
   write "Resend sc: ",sc,!
   halt
   EOF
   ```
   (no teste de 09/09/2026 o ID era `10`; **o ID muda a cada execução**,
   sempre confirmar pelo passo 4 antes de reenviar).
3. Confirmar `incident_INC-003.txt` em `out/`.

No Management Portal, o mesmo reenvio pode ser feito visualmente pelo
**Message Viewer**, selecionando a mensagem com erro e clicando em
**"Resend"** — mais direto para gravar em vídeo do que o comando.

## Resumo do que este experimento prova

| Afirmação do MVP (contexto, seção 2) | Evidência deste experimento |
|---|---|
| "uma falha controlada altera os indicadores" | Erro real (`#5005`) registrado em `Ens.MessageHeader`, arquivo de saída ausente |
| "pode ser rastreada até o evento original" | `Ens.MessageHeader` referencia o `INC-003` especificamente, com a cadeia Service→Process→Operation completa |
| "recuperação... são visíveis" | `INC-004` (tráfego novo) flui automaticamente após o conserto |
| "falha de coleta são visíveis" | Mensagem `INC-003` continua marcada como falha até reenvio manual — nada é escondido ou fingido como sucesso |

## Limpeza pós-experimento

Repetir o Passo 0 antes de gravar de novo, para começar sempre do mesmo
estado.

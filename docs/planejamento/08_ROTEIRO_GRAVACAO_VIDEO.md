# Roteiro de gravação — vídeo de apresentação

> Passo a passo operacional para o **proprietário gravar sozinho**, com
> tudo manuseado por ele: subir a aplicação, gerar o erro controlado,
> monitorar, perceber o erro, investigar e perguntar aos dois RAG.
> Baseado no fluxo já combinado em
> `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §8 e no roteiro
> reproduzível de `docs/experiments/01_falha_recuperacao_producao.md`.
> Este documento só organiza a ordem de gravação e o texto de apoio —
> os comandos técnicos completos, com o resultado real já observado,
> estão no experimento original; não duplicar aqui, referenciar.

## 0. Antes de gravar

- [ ] Fechar todas as abas/janelas com dados pessoais (e-mail, favoritos
  do navegador, outras abas do sistema operacional). O README e a
  auditoria de segredos (`06_FASE_5_HARDENING_TESTS_DEMO.md` §4) já
  identificaram a barra de favoritos do navegador como um vazamento de
  privacidade real em screenshots anteriores — **ocultar a barra de
  favoritos/abas antes de começar a gravar** (ou usar uma janela anônima
  sem favoritos salvos).
- [ ] Confirmar que nenhuma chave de API (Gemini, Groq) vai aparecer na
  tela — elas ficam em `Ens.Config.Credentials`, não em nenhuma tela de
  UI navegada durante a demo, então não há risco se você não abrir o
  Management Portal em `Interoperability → Configure → Credentials`.
- [ ] Container `iris-guardian` rodando: `docker start iris-guardian`
  (se já não estiver).
- [ ] Production no estado **Running**: no Management Portal
  (`http://localhost:53773/csp/sys/UtilHome.csp`, namespace `GUARDIAN`,
  login `guardian`/`guardian`) → Interoperability → Configure →
  Production, ou confirmar pelo Monitor da própria aplicação (ver passo
  2 abaixo — se `Estado` não for `Running`, seguir a nota de
  `RecoverProduction()` no fim deste documento antes de gravar).
- [ ] Estado limpo dos diretórios (Passo 0 do experimento):
  ```sh
  docker exec -i iris-guardian sh -c \
    'rm -f /durable/guardian/in/* /durable/guardian/archive/* /durable/guardian/out/* /durable/guardian/out_priority/* && \
     chmod 755 /durable/guardian/out /durable/guardian/out_priority'
  ```
- [ ] Decidir se vai gravar com narração ao vivo ou legendas/dublagem
  depois — o roteiro abaixo funciona para os dois casos, cada passo já
  tem uma frase pronta para narrar ou legendar.
- [ ] Fazer **um ensaio completo sem gravar** primeiro, do início ao
  fim, cronometrando. Corrigir qualquer trava antes da tomada real.

## 1. Abertura (30-60s)

Fala sugerida: apresentar o projeto (IRIS Production Guardian), os três
módulos (Production Monitor, AI Incident Investigator, RAG Assistant),
a versão/cenário da demo, e que a aplicação roda inteiramente sobre
InterSystems IRIS.

Tela: pode ser um slide simples ou a própria home/sidebar da aplicação
já logada, parada, antes de navegar.

## 2. Production saudável, mensagem atravessando os hosts (1-2 min)

1. Abrir `http://localhost:53773/csp/guardian/Guardian.UI.MonitorPage.cls`
   (login `guardian`/`guardian` se pedir). Mostrar `Estado: Running` e
   os hosts com badge `healthy`.
2. Disparar uma mensagem saudável, ao vivo, no terminal (aparecer na tela
   gravada, não só o resultado):
   ```sh
   docker exec -i iris-guardian sh -c \
     'echo "INC-BASE|IRIS.Service.OrderIngest|LOW|Fluxo normal, sem falha" > /durable/guardian/in/baseline.txt && \
      chown irisowner:irisowner /durable/guardian/in/baseline.txt'
   ```
3. Aguardar ~10s (o Service verifica a pasta a cada 5s) e mostrar o
   arquivo chegando:
   ```sh
   docker exec -i iris-guardian ls -la /durable/guardian/out
   ```
   Deve aparecer `incident_INC-BASE.txt`. Voltar ao Monitor na tela e
   apontar o indicador/horário de coleta se tiver mudado.

Fala sugerida: "aqui está o estado saudável — vou guardar essa imagem
para comparar depois da falha."

## 3. Introduzir a falha controlada (2-3 min)

Reproduzir exatamente o Passo 2 e Passo 3 de
`docs/experiments/01_falha_recuperacao_producao.md`:

1. Quebrar o destino ao vivo, na tela:
   ```sh
   docker exec -i iris-guardian chmod 555 /durable/guardian/out_priority
   ```
   Fala sugerida: "estou removendo a permissão de escrita do diretório
   de saída usado por incidentes críticos — simula um destino
   indisponível de verdade (disco cheio, permissão negada, share fora
   do ar), não uma falha fingida na interface."
2. Disparar o incidente que vai falhar:
   ```sh
   docker exec -i iris-guardian sh -c \
     'echo "INC-003|IRIS.Service.PaymentGateway|CRITICAL|Falha de escrita simulada no destino" > /durable/guardian/in/demo3.txt && \
      chown irisowner:irisowner /durable/guardian/in/demo3.txt'
   ```
3. Voltar para o Monitor na tela e **esperar ao vivo** (~15-20s, o
   `FailureTimeout` é real, não cortar esse tempo no vídeo — o roteiro
   de demo pede para não simular tempos falsos). Mostrar o componente
   `Guardian.Operation.PriorityOutputOperation` mudando para `degraded`.
4. Opcional, para reforçar que o erro é real e não uma simulação de
   UI: consultar `Ens.MessageHeader` ao vivo:
   ```sh
   docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
   set st=##class(%SQL.Statement).%New()
   set sc=st.%Prepare("SELECT ID, SourceConfigName, TargetConfigName, Status, ErrorStatus FROM Ens.MessageHeader ORDER BY ID DESC")
   set rs=st.%Execute()
   do rs.%Display()
   halt
   EOF
   ```
   Mostrar a linha com `ERROR #5005: Cannot open file
   '/durable/guardian/out_priority/incident_INC-003.txt'`.

Fala sugerida (repetir a do roteiro original): "aqui a falha é real,
não simulada na interface — o processo tentou escrever e o sistema
operacional recusou."

## 4. Abrir o incidente no AI Incident Investigator (2-3 min)

1. Navegar para
   `http://localhost:53773/csp/guardian/Guardian.UI.InvestigatorPage.cls`.
2. Selecionar o componente `Guardian.Operation.PriorityOutputOperation`
   (ou o incidente `INC-003`) e a janela de tempo que cobre o momento da
   falha.
3. Rodar a análise e **ler na tela, para a câmera**, a separação entre
   observação (o que os dados mostram), hipótese (o que provavelmente
   causou) e lacunas (o que não dá para afirmar com os dados
   disponíveis) — esse é o ponto central do DoD: "fundamenta hipóteses
   em evidências e não executa remediação automática". Não clicar em
   nada que sugira "corrigir automaticamente" — não existe esse botão,
   e a fala deve deixar claro que a decisão de corrigir é humana.

## 5. Perguntar aos dois RAG (3-4 min)

Perguntas já calibradas e testadas (`04_FASE_3_RAG_ASSISTANT.md` §7.1),
com resultado real conhecido — usar exatamente estas para garantir que
a gravação dá certo na primeira tentativa:

1. Abrir **RAG Assistant (Gemini)**
   (`Guardian.UI.RAGPage.cls`). Perguntar:
   > "Qual a causa do erro #5005?"

   Esperado: resposta com citação real de fonte (documento do corpus),
   ligando ao erro que acabou de ser gerado ao vivo no passo 3. Abrir a
   fonte citada na tela para mostrar que não é invenção.

2. Ainda no RAG (Gemini), perguntar uma pergunta **sem suporte no
   corpus**, para demonstrar abstenção:
   > "Qual a receita de bolo de chocolate?"

   Esperado: o modelo responde que não sabe / não há informação —
   **não deve inventar uma resposta**. Esse é o momento de narrar:
   "aqui o sistema se recusa a responder porque não há nada no corpus
   sobre isso — isso é a abstenção calibrada, não um bug."

3. Trocar para **RAG Assistant (Groq)**
   (`Guardian.UI.RAGAltPage.cls`) e repetir a pergunta 1 (
   "Qual a causa do erro #5005?"). Mostrar que o segundo provedor
   também responde com citação — reforça que retrieval/embeddings são
   os mesmos (Gemini) e só o modelo de geração muda.

Se alguma dessas perguntas não repetir o resultado esperado no dia da
gravação (ex.: corpus mudou), **não inventar** — gravar o resultado real
e ajustar a fala, nunca a tela.

## 6. Corrigir o destino e mostrar recuperação (2 min)

Reproduzir os Passos 5, 6 e 7 do experimento:

1. Corrigir a permissão:
   ```sh
   docker exec -i iris-guardian chmod 755 /durable/guardian/out_priority
   ```
2. Mostrar recuperação automática para tráfego novo:
   ```sh
   docker exec -i iris-guardian sh -c \
     'echo "INC-004|IRIS.Service.PaymentGateway|LOW|Fluxo normal apos recuperacao do destino" > /durable/guardian/in/demo4.txt && \
      chown irisowner:irisowner /durable/guardian/in/demo4.txt'
   ```
   Aguardar ~10s, mostrar `incident_INC-004.txt` aparecendo em `out/` e
   o Monitor voltando para `healthy`.
3. Explicar (sem precisar reenviar ao vivo, é opcional) que a mensagem
   `INC-003` que falhou **não** é reentregue sozinha — comportamento
   esperado do framework, não uma limitação — e que pode ser reenviada
   manualmente pelo Message Viewer do Management Portal (botão
   "Resend") ou por `Ens.MessageHeader.ResendMessage(<ID>)`. Se quiser
   mostrar isso na tela, é mais direto pelo Message Viewer (clicar em
   Resend) do que digitar o comando.

Fala sugerida: "o sistema se recupera sozinho para tráfego novo, sem
reiniciar nada — e nada foi escondido ou fingido como sucesso enquanto
a mensagem antiga continuava marcada como falha."

## 7. Bônus implementados (1-2 min)

Mostrar rapidamente, sem precisar operar ao vivo cada um:

- **Business Rules routing** — abrir
  `Guardian.Rule.IncidentRoutingRule` no Management Portal (editor
  visual de regras) e mostrar que a severidade decide o destino sem
  recompilar nada — é exatamente o que acabou de ser usado nos passos
  3 e 6 (`CRITICAL` → `out_priority`).
- **Hybrid search** — mencionar que a busca do RAG combina similaridade
  vetorial com busca lexical (iFind), sem precisar demonstrar
  interativamente.
- **PublicHealth bonus** — mencionar a segunda Production
  (`PublicHealthProduction`), que consome uma API pública real
  (`disease.sh`) e trata indisponibilidade sem inventar dados. Se
  quiser mostrar ao vivo, precisa parar `GuardianProduction` primeiro
  (só uma Production roda por namespace) — decidir se vale o tempo de
  vídeo ou só citar com print/trecho de código.

## 8. Metodologia com IA (1 min)

Citar `entregaveis/Prompts/` como evidência da sequência real de
prompts por fase/bônus, com os erros reais encontrados e corrigidos —
não precisa ler na tela, só apontar onde está.

## 9. Encerramento (30s)

Resumir os três módulos, os bônus, e onde encontrar o repositório e o
artigo da comunidade (aguardando link do Open Exchange — preencher
`entregaveis/Artigo_Comunidade_PT.md` depois que o vídeo tiver link
final).

## Limpeza pós-gravação

```sh
docker exec -i iris-guardian sh -c \
  'rm -f /durable/guardian/in/* /durable/guardian/archive/* /durable/guardian/out/* /durable/guardian/out_priority/*'
```

Deixar a Production `Running` (estado padrão entre sessões).

## Nota — se a Production não estiver Running antes de começar

```sh
docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
set sc=##class(Ens.Director).RecoverProduction()
write "Recover sc: ",sc,!
set sc=##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
write "Start sc: ",sc,!
halt
EOF
```

`RecoverProduction()` não recebe argumento nenhum (passar o nome da
Production dá erro `<PARAMETER>`) — chamar sempre antes do
`StartProduction` se a Production não foi desligada de forma limpa da
última vez.

## Checklist final antes de publicar o vídeo

- [ ] Nenhuma chave de API, senha ou dado pessoal visível em nenhum
  frame (revisar principalmente aberturas de terminal e barra de
  favoritos do navegador).
- [ ] Interface e texto em inglês na tela (requisito do concurso,
  `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §8) — a UI já
  suporta toggle PT/EN, deixar em EN antes de gravar as telas.
- [ ] Nenhum corte esconde uma espera real ou sugere um tempo falso de
  recuperação.
- [ ] Preencher, depois de publicado, o link do vídeo em
  `entregaveis/Artigo_Comunidade_PT.md`.

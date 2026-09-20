# Roteiro de gravação — vídeo de apresentação

> Passo a passo operacional **auto-suficiente** para o proprietário gravar
> sozinho: todo comando a rodar, toda URL a abrir e toda fala sugerida
> estão neste único documento — não é preciso abrir nenhum outro arquivo
> durante a gravação. (Reorganizado em 17/09/2026 para esse formato, a
> pedido do proprietário — `Ajustes.txt` item 5.1. As fontes originais,
> caso algum dia precise investigar mais fundo, são
> `docs/experiments/01_falha_recuperacao_producao.md` e
> `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md` §7.1, mas seu conteúdo
> relevante já está copiado aqui.)

**Login usado em toda a aplicação e no Management Portal:**
`guardian` / `guardian`.

**URLs que você vai abrir durante a gravação** (todas em
`http://localhost:53773/...`, ajuste a porta se o container publicar em
outra — confira com `docker port iris-guardian`):

http://localhost:53773/csp/sys/UtilHome.csp

http://localhost:53773/csp/guardian/Guardian.UI.MonitorPage.cls

| Tela | URL |
|---|---|
| Production Monitor | `/csp/guardian/Guardian.UI.MonitorPage.cls` |
| AI Incident Investigator | `/csp/guardian/Guardian.UI.InvestigatorPage.cls` |
| RAG Assistant (Gemini) | `/csp/guardian/Guardian.UI.RAGPage.cls` |
| RAG Assistant (Groq) | `/csp/guardian/Guardian.UI.RAGAltPage.cls` |
| Management Portal (home) | `/csp/sys/UtilHome.csp` |
| Production Configuration (editor visual) | `/csp/guardian/EnsPortal.ProductionConfig.zen?PRODUCTION=Guardian.Production.GuardianProduction` |
| Message Viewer | `/csp/guardian/EnsPortal.MessageViewer.zen` |
| Business Rule Editor (roteamento por severidade) | `/csp/guardian/EnsPortal.RuleEditor.zen?RULE=Guardian.Rule.IncidentRoutingRule.cls` |

Todos os comandos de terminal abaixo rodam no seu Mac (Terminal.app ou
iTerm), **não** dentro do container — eles chamam `docker exec` por fora.

## 0. Antes de gravar

- [ ] Fechar todas as abas/janelas com dados pessoais (e-mail, favoritos
  do navegador, outras abas do sistema operacional). Screenshots
  anteriores deste projeto já vazaram a barra de favoritos do navegador
  sem querer — **ocultar a barra de favoritos/abas antes de gravar** (ou
  usar uma janela anônima sem favoritos salvos).
- [ ] Confirmar que nenhuma chave de API (Gemini, Groq) vai aparecer na
  tela — elas ficam em `Ens.Config.Credentials`, tela que você não abre
  em nenhum passo deste roteiro (fica em Interoperability → Configure →
  Credentials no Management Portal). Só não abra essa tela específica e
  está seguro.
- [ ] Subir o container, se ainda não estiver rodando:
  ```sh
  docker start iris-guardian
  ```
- [ ] Confirmar que a Production está **Running**:
  ```sh
  docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
  write ##class(Ens.Director).GetProductionStatus(.tName,.tState),!
  write "Nome: ",tName," Estado: ",tState,!
  halt
  EOF
  ```
  Se `Estado` não for `1` (Running), rodar isto antes de continuar
  (`RecoverProduction()` não recebe argumento nenhum — passar o nome da
  Production dá erro `<PARAMETER>`):
  ```sh
  docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
  set sc=##class(Ens.Director).RecoverProduction()
  write "Recover sc: ",sc,!
  set sc=##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
  write "Start sc: ",sc,!
  halt
  EOF
  ```
- [ ] Deixar os diretórios de mensagens em estado limpo:
  ```sh
  docker exec -i iris-guardian sh -c \
    'rm -f /durable/guardian/in/* /durable/guardian/archive/* /durable/guardian/out/* /durable/guardian/out_priority/* && \
     chmod 755 /durable/guardian/out /durable/guardian/out_priority'
  ```
- [ ] Deixar uma segunda janela de terminal pronta (split de tela ou
  picture-in-picture) — é nela que o loop de tráfego contínuo da seção 2
  vai rodar, visível do início ao fim da gravação.
- [ ] **Dar um refresh forçado no navegador** antes de começar (Chrome
  no Mac: botão direito no ícone de recarregar com o DevTools aberto →
  "Esvaziar cache e atualização forçada", ou Cmd+Shift+R). A UI recebeu
  ajustes de CSS em 17/09/2026 (loader, logo); um cache antigo pode
  mostrar a logo do loader gigante/cortada em vez do badge pequeno e
  elegante.
- [ ] No canto superior da sidebar da aplicação, clicar no botão de
  idioma até ficar **EN** (requisito do concurso: interface em inglês
  na gravação). Confirmar que título da aba do navegador também mudou
  para inglês em cada página que for abrir.
- [ ] Decidir se vai gravar com narração ao vivo ou legendas/dublagem
  depois — cada passo abaixo já tem uma frase pronta para narrar ou
  legendar.
- [ ] Fazer **um ensaio completo sem gravar** primeiro, do início ao
  fim, cronometrando. Corrigir qualquer trava antes da tomada real.

## 1. Abertura (30-60s)

Tela: slide simples, ou a própria home/sidebar da aplicação já logada
(`/csp/guardian/Guardian.UI.MonitorPage.cls`), parada, antes de navegar.

Fala sugerida: apresentar o projeto (IRIS Production Guardian), os três
módulos (Production Monitor, AI Incident Investigator, RAG Assistant),
e que a aplicação roda inteiramente sobre InterSystems IRIS.

## 2. Production saudável, mensagens atravessando os hosts em tempo real (1-2 min)

1. Abrir `http://localhost:53773/csp/guardian/Guardian.UI.MonitorPage.cls`
   (login `guardian`/`guardian` se pedir). Mostrar `State: Running` e os
   hosts com badge `healthy`.
2. Na segunda janela de terminal, iniciar o loop de tráfego contínuo —
   manda uma mensagem `LOW` a cada 6 segundos, para o Monitor parecer
   uma produção viva (contadores de fila/mensagens se movendo o tempo
   todo) em vez de um disparo único e estático:
   ```sh
   I=0
   while true; do
     I=$((I + 1))
     ID="LOOP-$(date +%H%M%S)-${I}"
     FILE="loop_${I}.txt"
     docker exec -i iris-guardian sh -c \
       "echo '${ID}|IRIS.Service.OrderIngest|LOW|Trafego continuo de demonstracao #${I}' > /durable/guardian/in/${FILE} && chown irisowner:irisowner /durable/guardian/in/${FILE}"
     echo "[$(date +%T)] enviado ${ID}"
     sleep 6
   done
   ```
   (Isto é o conteúdo de `docs/experiments/loop_trafego_saudavel.sh` —
   pode rodar `sh docs/experiments/loop_trafego_saudavel.sh` em vez de
   colar o bloco acima, dá no mesmo. Aceita um número como argumento
   para trocar o intervalo, ex. `sh docs/experiments/loop_trafego_saudavel.sh 10`.)

   Deixar rodando em primeiro plano nessa janela **durante toda a
   gravação** (seções 2 a 7) — só interromper com Ctrl+C na seção de
   limpeza, no final. Cada mensagem é severidade `LOW`, roteada para
   `/durable/guardian/out` (via `Guardian.Operation.FileOutputOperation`);
   não interfere na falha controlada da seção 3, que afeta só
   `/durable/guardian/out_priority` (destino exclusivo de
   `CRITICAL`/`HIGH`/`MEDIUM`, decidido por
   `Guardian.Rule.IncidentRoutingRule` — bônus de Business Rules).
3. Voltar para o Monitor na tela e apontar o horário de coleta e os
   contadores de fila/mensagens mudando a cada ~6s, conforme o loop
   envia. Opcional, para reforçar que é tráfego real chegando por
   arquivo, não simulado na interface:
   ```sh
   docker exec -i iris-guardian ls -la /durable/guardian/out
   ```

Fala sugerida: "aqui está o estado saudável, com tráfego real entrando
continuamente — vou guardar essa imagem para comparar depois da falha."

## 3. Introduzir a falha controlada (2-3 min)

1. Quebrar o destino ao vivo, na tela:
   ```sh
   docker exec -i iris-guardian chmod 555 /durable/guardian/out_priority
   ```
   Isso remove a permissão de escrita do usuário `irisowner` (dono do
   processo IRIS) no diretório de saída usado por incidentes
   `CRITICAL`/`HIGH`/`MEDIUM` — simula um destino indisponível de
   verdade (disco cheio, permissão negada, share fora do ar), sem tocar
   em nada dentro do IRIS.

   Fala sugerida: "estou removendo a permissão de escrita do diretório
   de saída usado por incidentes críticos — simula um destino
   indisponível de verdade, não uma falha fingida na interface."
2. Disparar o incidente que vai falhar:
   ```sh
   docker exec -i iris-guardian sh -c \
     'echo "INC-003|IRIS.Service.PaymentGateway|CRITICAL|Falha de escrita simulada no destino" > /durable/guardian/in/demo3.txt && \
      chown irisowner:irisowner /durable/guardian/in/demo3.txt'
   ```
3. Voltar para o Monitor na tela e **esperar ao vivo** (~15-20s — o
   `FailureTimeout` padrão do `Ens.BusinessOperation` é real, não cortar
   esse tempo no vídeo). Mostrar o componente
   `Guardian.Operation.PriorityOutputOperation` mudando para `degraded`.
   Nesse meio-tempo o loop de tráfego (seção 2) continua rodando na
   outra janela — apontar que os contadores de
   `Guardian.Operation.FileOutputOperation` (caminho normal, severidade
   LOW) continuam subindo normalmente enquanto só o operation de saída
   prioritária degrada.

   Fala sugerida: "note que o tráfego normal continua passando sem
   problema — só o caminho de incidentes críticos foi afetado, a falha
   é isolada, não derrubou a Production inteira."
4. Confirmar o erro real via SQL ao vivo (guardar o `ID` da última
   linha com `TargetConfigName = Guardian.Operation.FileOutputOperation`
   e `ErrorStatus` diferente de `1` — vai precisar dele na seção 6 se
   for demonstrar o reenvio manual):
   ```sh
   docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
   set st=##class(%SQL.Statement).%New()
   set sc=st.%Prepare("SELECT ID, SourceConfigName, TargetConfigName, Status, ErrorStatus FROM Ens.MessageHeader ORDER BY ID DESC")
   set rs=st.%Execute()
   do rs.%Display()
   halt
   EOF
   ```
   Deve aparecer `ERROR #5005: Cannot open file
   '/durable/guardian/out_priority/incident_INC-003.txt'`, embrulhado em
   `<Ens>ErrFailureTimeout`. Alternativa visual (mais direta para
   gravar): abrir o Message Viewer em
   `http://localhost:53773/csp/guardian/EnsPortal.MessageViewer.zen` e
   mostrar a mensagem com erro na lista.

   Fala sugerida: "aqui a falha é real, não simulada na interface — o
   processo tentou escrever e o sistema operacional recusou."

## 4. Abrir o incidente no AI Incident Investigator (2-3 min)

1. Navegar para
   `http://localhost:53773/csp/guardian/Guardian.UI.InvestigatorPage.cls`.
2. Selecionar o componente `Guardian.Operation.PriorityOutputOperation`
   e uma janela de tempo que cubra o momento da falha (ex. 60 minutos).
3. Clicar em "Investigate". A tela escurece com um overlay (logo
   Production Guardian + spinner animado) até a análise da IA terminar
   — comportamento normal, não é travamento; o overlay fica visível
   durante todo o processamento real, inclusive se a chamada à IA
   demorar vários segundos. Bom momento para narrar "a IA está
   analisando agora, em tempo real".
4. Rodar a análise e **ler na tela, para a câmera**, a separação entre
   observação (o que os dados mostram), hipótese (o que provavelmente
   causou) e lacunas (o que não dá para afirmar com os dados
   disponíveis) — esse é o ponto central do DoD: "fundamenta hipóteses
   em evidências e não executa remediação automática". Não clicar em
   nada que sugira "corrigir automaticamente" — não existe esse botão,
   e a fala deve deixar claro que a decisão de corrigir é humana.

## 5. Perguntar aos dois RAG Assistants (3-4 min)

Perguntas já calibradas contra o corpus real do projeto (10 perguntas
testadas, limiar de abstenção 0.58; as relevantes ficaram entre
0.668-0.761 de similaridade, as irrelevantes entre 0.507-0.521 — gap
limpo, sem ambiguidade). Usar exatamente as perguntas abaixo para
garantir que a gravação dá certo na primeira tentativa. Assim como no
Investigator (seção 4), clicar em "Ask"/"Perguntar" escurece a tela com
o mesmo overlay de carregamento até a resposta chegar — normal, não
cortar.

1. Abrir **RAG Assistant (Gemini)**:
   `http://localhost:53773/csp/guardian/Guardian.UI.RAGPage.cls`.
   Perguntar:
   > "Qual a causa do erro #5005?"

   Esperado: resposta com citação real de fonte (documento do corpus,
   similaridade ~0.67), ligando ao erro que acabou de ser gerado ao
   vivo na seção 3. Abrir a fonte citada na tela para mostrar que não é
   invenção.

2. Ainda no RAG (Gemini), perguntar uma pergunta **sem suporte no
   corpus**, para demonstrar abstenção:
   > "Qual a receita de bolo de chocolate?"

   Esperado: o modelo responde que não sabe / não há informação
   (similaridade real ~0.52, abaixo do limiar 0.58) — **não deve
   inventar uma resposta**. Momento de narrar: "aqui o sistema se
   recusa a responder porque não há nada no corpus sobre isso — isso é
   a abstenção calibrada, não um bug."

3. Trocar para **RAG Assistant (Groq)**:
   `http://localhost:53773/csp/guardian/Guardian.UI.RAGAltPage.cls` e
   repetir a pergunta 1 ("Qual a causa do erro #5005?"). Mostrar que o
   segundo provedor também responde com citação — reforça que
   retrieval/embeddings são os mesmos (Gemini) e só o modelo de geração
   muda (Groq, `openai/gpt-oss-120b`).

Se alguma dessas perguntas não repetir o resultado esperado no dia da
gravação (ex.: corpus mudou), **não inventar** — gravar o resultado real
e ajustar a fala, nunca a tela.

## 6. Corrigir o destino e mostrar recuperação (2 min)

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
3. Explicar que a mensagem `INC-003` que falhou **não** é reentregue
   sozinha — o `FailureTimeout` já expirou antes do destino ser
   corrigido, então aquela tentativa específica ficou definitivamente
   marcada como falha (comportamento real e documentado do framework,
   não uma limitação do código). Duas formas de mostrar o reenvio
   manual, se quiser demonstrar ao vivo (opcional):
   - **Pelo Message Viewer** (mais direto para gravar):
     `http://localhost:53773/csp/guardian/EnsPortal.MessageViewer.zen`
     → selecionar a mensagem do `INC-003` com erro → botão **Resend**.
   - **Por comando**, usando o `ID` anotado na seção 3, passo 4:
     ```sh
     docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
     set sc=##class(Ens.MessageHeader).ResendMessage(<ID_DA_MENSAGEM>)
     write "Resend sc: ",sc,!
     halt
     EOF
     ```
   Confirmar `incident_INC-003.txt` aparecendo em `out_priority/` depois
   do reenvio.

Fala sugerida: "o sistema se recupera sozinho para tráfego novo, sem
reiniciar nada — e nada foi escondido ou fingido como sucesso enquanto
a mensagem antiga continuava marcada como falha."

## 7. Bônus implementados (1-2 min)

Mostrar rapidamente, sem precisar operar ao vivo cada um:

- **Business Rules routing** — abrir
  `http://localhost:53773/csp/guardian/EnsPortal.RuleEditor.zen?RULE=Guardian.Rule.IncidentRoutingRule.cls`
  (editor visual de regras) e mostrar que a severidade decide o destino
  sem recompilar nada — é exatamente o que acabou de ser usado nas
  seções 3 e 6 (`CRITICAL` → `out_priority`).
- **Hybrid search** — mencionar que a busca do RAG combina similaridade
  vetorial com busca lexical (iFind), sem precisar demonstrar
  interativamente.
- **PublicHealth bonus** — mencionar a segunda Production
  (`PublicHealthProduction`), que consome uma API pública real
  (`disease.sh`) e trata indisponibilidade sem inventar dados. Se
  quiser mostrar ao vivo (só uma Production roda por namespace, então
  precisa parar a atual primeiro — decidir se vale o tempo de vídeo ou
  só citar com print/trecho de código):
  ```sh
  docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
  do ##class(Ens.Director).StopProduction()
  set sc=##class(Ens.Director).StartProduction("Guardian.Production.PublicHealthProduction")
  write "Start PublicHealth sc: ",sc,!
  halt
  EOF
  ```
  Para voltar à Production principal depois (necessário para o resto do
  roteiro, se gravar isso fora de ordem):
  ```sh
  docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
  do ##class(Ens.Director).StopProduction()
  set sc=##class(Ens.Director).RecoverProduction()
  set sc=##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
  write "Start Guardian sc: ",sc,!
  halt
  EOF
  ```

## 8. Metodologia com IA (1 min)

Mostrar a pasta `entregaveis/Prompts/` no Finder ou editor de código —
10 arquivos com a sequência real de prompts por fase/bônus, com os erros
reais encontrados e corrigidos. Não precisa ler o conteúdo na tela, só
apontar que existe e abrir um arquivo rapidamente como exemplo.

## 9. Encerramento (30s)

Resumir os três módulos, os bônus, e onde encontrar o repositório. Se
já tiver o link do artigo da comunidade publicado, mencionar; senão,
deixar essa parte para depois (o link do vídeo em si e o do Open
Exchange ainda precisam ser preenchidos em
`entregaveis/Artigo_Comunidade_PT.md` depois que o vídeo estiver
publicado).

## Limpeza pós-gravação

1. Parar o loop de tráfego (seção 2) — Ctrl+C na janela onde ele está
   rodando, ou, se foi deixado em segundo plano: `pkill -f
   loop_trafego_saudavel` (ou `pkill -f "durable/guardian/in"` se rodou
   o bloco colado em vez do script).
2. Limpar os diretórios:
   ```sh
   docker exec -i iris-guardian sh -c \
     'rm -f /durable/guardian/in/* /durable/guardian/archive/* /durable/guardian/out/* /durable/guardian/out_priority/*'
   ```
3. Deixar a Production `Running` (estado padrão entre sessões) — se
   tiver testado o bônus PublicHealth (seção 7), confirmar que voltou
   para `Guardian.Production.GuardianProduction`, não
   `PublicHealthProduction`.

## Checklist final antes de publicar o vídeo

- [ ] Nenhuma chave de API, senha ou dado pessoal visível em nenhum
  frame (revisar principalmente aberturas de terminal e barra de
  favoritos do navegador).
- [ ] Interface e texto em inglês na tela (requisito do concurso) — o
  toggle EN no canto superior da sidebar reflete corretamente em todas
  as 4 páginas (auditado em 17/09/2026).
- [ ] Nenhum corte esconde uma espera real ou sugere um tempo falso de
  recuperação.
- [ ] Preencher, depois de publicado, o link do vídeo em
  `entregaveis/Artigo_Comunidade_PT.md`.

# Fase 5 — Hardening, testes, instalação limpa e demo

> Responsabilidade declarada em `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`
> §6: "Integração final, segurança, instalação reproduzível e gravação".
> Critérios de aceite vêm da Definition of Done (§11 do mesmo documento) e
> do fluxo de demo (§8). Fases 0-4 estão completas (ver
> `00_MASTER_PLAN.md` §2) - esta fase não adiciona funcionalidade nova ao
> MVP, fecha o que falta para a entrega ser defensável.

## 1. Escopo

Da Definition of Done (itens ainda não marcados) e do cronograma
(18-19/09, depois 20/09 para demo):

1. **Instalação a partir de checkout limpo** - reproduzir o setup do
   zero (container novo, `docker cp` dos assets estáticos, compilação
   das classes, criação de namespace/produção) seguindo só o que está
   escrito no `README.md`, sem atalho de memória do que já foi feito
   manualmente antes. Qualquer passo que só funcionou porque o
   ambiente atual já tinha algo configurado à mão vira lacuna do
   README.
2. **Testes cobrindo os quatro caminhos exigidos pelo DoD §11**:
   - Percurso completo (mensagem saudável ponta a ponta).
   - Falha do destino (já coberto por
     `docs/experiments/01_falha_recuperacao_producao.md` - reconfirmar
     que continua reproduzível depois de todas as mudanças de UI).
   - Falta de dados (componente sem eventos na janela, Monitor sem
     hosts, RAG sem documentos relevantes - abstenção).
   - Indisponibilidade de modelo/API (Gemini 503/429 - já observado
     organicamente em sessões anteriores; formalizar como teste
     repetível, não só um acidente que aconteceu durante outro teste).
3. **Segurança / segredos** - conferir que nenhuma credencial (a senha
   `guardian`/`guardian`, chave do Gemini) está em código versionado,
   log publicado, prompt de exemplo ou vídeo. `Ens.Config.Credentials`
   já tira a chave do código-fonte; falta a auditoria final antes de
   publicar.
4. **Fechar pendências críticas documentadas no scorecard** - revisar
   `07_SCORECARD_EVIDENCIAS.md` e `00_MASTER_PLAN.md` §5 e confirmar
   que nenhum item marcado como pronto tem um `VERIFY_REQUIRED` aberto
   por trás.
5. **Preparação de demo/vídeo** - roteiro já existe (contexto §8);
   falta gravar, com carga/falha/recuperação repetíveis e sem expor
   credenciais.
6. **Artigo da comunidade** - conteúdo ainda não iniciado (contexto
   §9, §11).

Fora do escopo desta fase (decisão já registrada, não reabrir aqui):
IntegratedML (bloqueado, VR-003) e multimodelo/API pública como
funcionalidade nova - isso é backlog do MVP, não hardening.

## 2. Estado em 11/09/2026 - fase iniciada, só escopo por enquanto

Nenhum item de execução abaixo foi concluído ainda. Este documento
registra o escopo combinado com o proprietário; a ordem de execução
dentro da fase (qual item da tabela abaixo entra primeiro) ainda
depende de decisão dele.

| # | Item | Status |
|---|---|---|
| 1 | Instalação a partir de checkout limpo | **Feita 13/09/2026** — ver §6. README corrigido com 6 lacunas reais encontradas |
| 2 | Teste formal: percurso completo | **Feito 13/09/2026** — ver §5 |
| 3 | Teste formal: falha de destino | **Refeito e corrigido 13/09/2026** — ver §5. `docs/experiments/01_falha_recuperacao_producao.md` estava desatualizado pelo roteamento por Business Rules, corrigido |
| 4 | Teste formal: falta de dados | **Feito 13/09/2026** — ver §5 |
| 5 | Teste formal: indisponibilidade de modelo/API | **Feito 13/09/2026** — formalizado como caso repetível, ver §5 |
| 6 | Auditoria de segredos | **Quase feita, 13/09/2026** — ver §4 abaixo. Nenhum segredo real encontrado em código/histórico do git. Achado de privacidade (não segredo) nos screenshots do manual: PNGs soltos e `.docx` (PT/EN) já corrigidos; falta regenerar o `.pdf` a partir do `.docx` corrigido — bloqueado numa permissão do macOS que só o proprietário aprova fisicamente |
| 7 | Fechamento de pendências no scorecard | Feito 11/09/2026 para o bônus API pública (PublicHealth), que estava implementado e testado mas não refletido em `00_MASTER_PLAN.md`/`07_SCORECARD_EVIDENCIAS.md`. Demais itens do scorecard seguem corretos |
| 8 | Gravação do vídeo | Não iniciado |
| 9 | Artigo da comunidade | **Rascunho criado 13/09/2026** (`entregaveis/Artigo_Comunidade_PT.md`) — falta preencher link do Open Exchange e do vídeo, adicionar capturas de tela reais, revisão do proprietário e publicação |

## 3. Pendente

Itens 8 e 9 da tabela acima (mais a regeneração do PDF do manual, ver
§4, e o script de reingestão do corpus RAG, ver §6). Ver
`00_MASTER_PLAN.md` §5 para o registro cronológico de pendências e
`07_SCORECARD_EVIDENCIAS.md` para evidência item a item.

## 4. Auditoria de segredos (13/09/2026) — resultado

Escopo: nenhuma credencial (senha `guardian`/`guardian`, chaves Gemini e
Groq) em código versionado, histórico do git ou documentação publicada.

**Verificado, nada encontrado:**
- `git grep` no working tree (código-fonte) por padrões de chave
  (`gsk_...`, `AIza...`, `password = "..."`, `api_key = "..."`) — zero
  ocorrências.
- `git log --all -S"<padrão>"` (pickaxe, varre **todo o histórico**, não
  só o HEAD atual — importante porque o repo é público e um segredo já
  removido continuaria exposto no histórico) para `gsk_`, `AIza`,
  `sk-`, `IRIS_PASSWORD=`, `Password = "guardian"` — zero ocorrências
  reais (um falso positivo de `sk-` caiu dentro de bytes binários de PNG,
  não é texto).
- `pessoal/` (contém a credencial em texto puro `Anotações para
  Usuário.txt`) confirmado **nunca rastreado** pelo git, desde o
  primeiro commit — sempre no `.gitignore`, junto com
  `Imagens/Error/`.
- `.vscode/settings.json` (rastreado) só guarda host/porta/namespace/
  username (`guardian`) da extensão ObjectScript — sem senha.
- `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md` usa
  `<CHAVE_REAL_AQUI>` como placeholder no snippet de setup — nunca a
  chave de verdade.
- A chave Groq real (recebida ao vivo nesta sessão, 13/09/2026) foi
  usada só em comandos efêmeros (`iris session` via heredoc) e salva
  direto em `Ens.Config.Credentials` dentro do IRIS — nunca tocou um
  arquivo do repositório; confirmado por pickaxe (`gsk_` acima).

**Achado — não é segredo, é privacidade — corrigido 13/09/2026:** os 7
screenshots em `entregaveis/manual_assets/*.png` (arquivos-fonte soltos
no repositório, navegáveis diretamente no GitHub) mostravam a barra de
favoritos/abas do navegador do proprietário por inteiro: início do
e-mail pessoal ("Entrada - sergiofs...") e nomes de pastas pessoais
(`DESPESAS`, `Corretagem`, `Empresa`, `Estudo`). Nenhuma senha ou chave
apareceu em nenhuma delas. Recortadas (removidos os primeiros 104px de
altura de cada uma, região da barra de abas/URL/favoritos, verificado
pixel a pixel) e sobrescritas no repositório.

**Verificação extra (13/09/2026): o conteúdo *visível* do `.docx`/`.pdf`
já montados nunca mostrou a barra de favoritos.** Antes de recortar o
`.docx`, abri o pacote (é um zip) e conferi `word/document.xml` — cada
uma das 7 imagens já tinha um retângulo de corte do Word (`a:srcRect`)
aplicado manualmente pelo proprietário ao montar o manual, com corte
superior mínimo de 14,5% da altura (111px de 768) — sempre abaixo da
linha da barra de abas/favoritos (104px). Renderizado o corte real de
duas imagens e a página 3 do PDF (dpi 150) para confirmar visualmente:
nenhuma mostra o navegador.

**Porém o *asset bruto embutido* (não o que aparece na tela) ainda era o
screenshot completo sem corte** — em ambos os formatos: `python3 -c
"import zipfile"` no `.docx` e `PyMuPDF` no `.pdf` confirmam que a
imagem de 1314×768 fica embutida por inteiro, e só a instrução de
recorte do Word decide o que é exibido. Ou seja, alguém que extraia as
imagens de dentro do arquivo (como fiz para auditar) veria a barra de
favoritos, mesmo sem ela aparecer ao ler o documento normalmente —
mesma categoria de exposição dos PNGs soltos, só que dentro do binário.

**Corrigido nos `.docx` (13/09/2026):** as 7 imagens embutidas foram
substituídas pelas versões já cortadas (sem os 104px do topo) nos dois
manuais (PT e EN), e o retângulo de corte do Word (`a:srcRect`) foi
recalculado matematicamente para cada uma (mantendo `l`/`r`, só `t`/`b`
mudam porque a altura da imagem-fonte mudou de 768 para 664px) — não
reaberto no Word, editado direto no XML do pacote. Validado renderizando
o corte resultante com os novos valores e comparando pixel a pixel com o
corte antigo: idêntico, sem regressão visual, em ambos os manuais.

**Pendente: regenerar `Manual_IRIS_Production_Guardian.pdf` a partir do
`.docx` corrigido.** O PDF não tem um "retângulo de corte" editável como
o `.docx` (a instrução de corte no PDF é outro mecanismo, embutida no
content stream da página) — a forma correta e de baixo risco de corrigir
é reexportar do `.docx` já corrigido pelo próprio Word, não editar o PDF
byte a byte. Tentativa de automação via AppleScript (13/09/2026) travou
esperando uma permissão do macOS (diálogo de Automação/Controle do
sistema para o Word/System Events) que só o proprietário pode aprovar
fisicamente na tela — ele estava fora do computador nesse momento.
**Próxima vez que estiver no computador:** abrir
`entregaveis/Manual_IRIS_Production_Guardian.docx` no Word → Arquivo →
Salvar Como → PDF, sobrescrevendo `entregaveis/Manual_IRIS_Production_Guardian.pdf`
(ou aprovar o diálogo de permissão do macOS se pedir para repetir a
automação). Não há PDF da versão EN para regenerar (só existe o `.docx`
EN hoje).

## 5. Testes formais dos 4 caminhos do DoD (13/09/2026) — resultado

**Achado antes de começar:** a Production estava **parada**
(`IsProductionRunning()=0`, status interno `4`) no início da sessão —
não "Com problema" como os screenshots antigos do manual sugeriam, mas
efetivamente desligada. `StartProduction` sozinho falhou com
`<Ens>ErrProductionNotShutdownCleanly`; precisou de
`##class(Ens.Director).RecoverProduction()` (sem argumentos — passar o
nome da Production dá `<PARAMETER>` error, diferente do que uma memória
antiga presumia) antes do `StartProduction` funcionar. Mesmo pitfall já
documentado em memória do projeto, agora também formalizado aqui.

**Teste 1 — Percurso completo:** mensagem `LOW` (`INC-FASE5-BASE`) via
`Guardian.Service.FileIncidentService` → `Guardian.Process.IncidentRouterProcess`
→ `Guardian.Operation.FileOutputOperation`, arquivo gerado em
`/durable/guardian/out` em ~10s. Monitor confirmado via HTTP real (login
`guardian`/`guardian`): `Estado: Running`, os 4 hosts `healthy`. **OK.**

**Teste 2 — Falha de destino:** reprodução do roteiro completo
(`docs/experiments/01_falha_recuperacao_producao.md`), com uma correção
real encontrada no processo — ver a nota no próprio arquivo: severidade
`CRITICAL` hoje roteia para `Guardian.Operation.PriorityOutputOperation`
(`/durable/guardian/out_priority`), não mais para
`Guardian.Operation.FileOutputOperation` (`/durable/guardian/out`) como
na primeira versão do roteiro (anterior ao bônus Business Rules,
10/09/2026). Quebrar o diretório errado (`out`) com uma mensagem
`CRITICAL` **não causa falha nenhuma** — confirmado ao vivo antes de
corrigir. Refeito quebrando `/durable/guardian/out_priority`: erro real
capturado (`ERROR #5005: Cannot open file
'/durable/guardian/out_priority/incident_INC-FASE5-004.txt'`,
embrulhado em `<Ens>ErrFailureTimeout`), badge do componente muda para
`degraded` no Investigator. Corrigido o destino: tráfego novo
(`INC-FASE5-005`) entregue automaticamente; a mensagem que falhou não é
reentregue sozinha (comportamento esperado do framework) —
`##class(Ens.MessageHeader).ResendMessage(<id>)` reentrega manualmente e
confirmado o arquivo em `out_priority`. **OK, roteiro do experimento
corrigido para refletir a rota atual.**

**Teste 3 — Falta de dados:**
- RAG Assistant, pergunta irrelevante ("Qual a receita de bolo de
  chocolate?") com uma investigação recente ainda em contexto: o modelo
  respondeu "Não sei..." em vez de inventar — abstenção correta, mas via
  o LLM (não o `abstained=1` hardcoded, que só dispara quando não há
  nem documentos relevantes nem investigação em contexto; aqui havia
  investigação, então o código intencionalmente deixa o modelo decidir
  com esse grounding, ver comentário em `Guardian.RAG.Query.Ask`). O
  caminho hardcoded (zero contexto e zero documentos relevantes) já
  tinha sido calibrado e testado em `04_FASE_3_RAG_ASSISTANT.md` §5.
- AI Incident Investigator, `Guardian.Service.FileIncidentService` com
  janela de 1 minuto após 65s sem tráfego algum: `0 eventos registrados
  na janela`, análise da IA relatou isso corretamente sem inventar
  eventos. **OK.**

**Teste 4 — Indisponibilidade de modelo/API:** formalizado como caso
determinístico, não dependente de esperar um 429/503 real acontecer por
acaso. Numa única sessão COS: leu a senha real da credencial `Gemini`
para uma variável local (nunca impressa), trocou temporariamente por um
valor inválido, chamou `Guardian.RAG.GeminiClient.Generate` diretamente
(erro real da API: `HTTP 400: API key not valid. Please pass a valid API
key.`, capturado como exceção COS não tratada — mesmo tipo de erro que o
`Catch` de `Guardian.UI.RAGPage`/`InvestigatorPage` já trata e exibe como
indisponibilidade, sem inventar resposta), e restaurou a senha original
antes de sair da sessão. Sanity check com uma chamada real depois
(`"responda apenas OK"` → `"OK"`) confirmou a chave restaurada
corretamente, sem dano permanente. **OK.**

**Limpeza:** `/durable/guardian/{in,archive,out,out_priority}`
esvaziados ao final, Production deixada `Running` (estado padrão entre
sessões).

## 6. Instalação a partir de checkout limpo (13/09/2026) — resultado

Container Docker novo (`iris-guardian-clean`, volume nomeado novo,
portas `51974`/`53775` para não colidir com o `iris-guardian` real),
seguindo **só** o que estava escrito no README, sem nenhum atalho do
ambiente já configurado à mão. Onde o README mandava usar o Management
Portal (GUI, não roteável por automação headless), substituí por
chamadas COS equivalentes documentadas nesta seção — mais rápido de
verificar e também mais fácil de reproduzir num CI, então o achado virou
correção direta no README (agora oferece as duas formas).

**Seis lacunas reais encontradas e corrigidas no README nesta sessão:**

1. **Tabela "Project status" completamente desatualizada** — dizia que
   Monitor/Investigator/RAG/Business Rules "not started", quando os
   quatro estavam prontos e testados há dias. Corrigida.
2. **"Interoperability enabled" não tem equivalente scriptável
   documentado** — `Config.Namespaces.Create` sozinho não habilita
   interoperabilidade (classes `Ens.*` não compilam: `ERROR #5373: Class
   'Ens.Production'... does not exist`). Descoberto por tentativa e erro
   consultando `%Dictionary.PropertyDefinition` de `Config.Namespaces`:
   existe uma propriedade `Interop` (`Config.Namespaces.Modify(ns,
   .props)` com `props("Interop")=1`) que resolve, sem precisar
   recriar o namespace. Adicionado ao README como alternativa à GUI.
3. **Diretórios `/durable/guardian/{in,archive,out,out_priority}` não
   são criados por nada** — nem pelo `StartProduction`, nem pelos
   adaptadores de arquivo. Sem esse passo (ausente do README), a
   Production sobe mas todo host de arquivo fica quebrado silenciosamente
   até alguém enviar a primeira mensagem e descobrir pelo erro.
4. **Passo de assets estava incompleto** — copiava só o logo e o CSS,
   faltando o logo dark-mode e o spinner de loading (`RAG Assistant`/
   `Investigator` referenciam `/csp/guardian/iris-guardian-spinner.png`).
   Pior: **`iris-guardian-spinner.png` nunca tinha sido commitado no
   repositório** — existia só dentro do container em produção, copiado
   manualmente numa sessão anterior. Um `git clone` limpo perderia esse
   arquivo para sempre, sem nenhum jeito de recriá-lo a partir do repo.
   Resgatado do container real e adicionado a `assets/`.
5. **Nenhuma menção a SSL config ou credenciais de IA** — sem
   `Security.SSLConfigs` (`PublicHTTPS`) e sem `Ens.Config.Credentials`
   para `Gemini`/`Groq`, o Investigator/RAG carregam normalmente mas toda
   pergunta de IA falha. Comportamento gracioso confirmado ao vivo (sem
   credencial: `ERROR <Ens>ErrNoCredentialsSystemName`, HTTP 200, mensagem
   real de indisponibilidade, sem inventar resposta) — mas o README nunca
   dizia que esse passo existia. Adicionado, incluindo onde conseguir as
   chaves gratuitas de cada provedor.
6. **Nenhuma das 4 classes `*.Schema.Setup()` (RAG, Monitor,
   Investigator, PublicHealth) está documentada** — elas criam as
   próprias tabelas SQL via `CREATE TABLE IF NOT EXISTS` na primeira
   execução, não ao compilar a classe. Sem chamar isso manualmente uma
   vez, toda página falha com `Statement not prepared` - fácil de
   confundir com erro de compilação. Adicionado ao README como passo
   próprio, antes de criar os diretórios/iniciar a Production.

**Verificado funcionando de ponta a ponta depois de fechar as 6
lacunas:** namespace/DB criados, 30 classes compiladas sem erro, 4
schemas criados, diretórios criados, Production iniciada, assets
servidos, SSL configurado, credencial Gemini real transferida do
container de produção **sem nunca aparecer na saída de texto** (exportada
para um arquivo no scratchpad, copiada via `docker cp`, importada por
COS, arquivos temporários apagados dos dois lados), ingestão real de um
documento (`Guardian.RAG.Ingestion.IngestFile`), e as páginas RAG
Assistant e AI Incident Investigator respondendo com citação real a
partir do corpus recém-ingerido — tudo isso num container que não existia
15 minutos antes.

**Achado sem correção ainda (não é lacuna do README, é lacuna de
conteúdo):** o corpus real em uso (12 documentos: 7 arquivos locais de
`docs/planejamento/` + 5 páginas públicas da InterSystems Developer
Community/docs, buscadas e ingeridas manualmente ao longo de várias
sessões) não tem um script ou lista reproduzível em lugar nenhum do
repositório — só existe como estado acumulado no volume Docker de
produção. Lista completa capturada nesta sessão via SQL
(`SELECT Source,Title,Version FROM Guardian_RAG.Document`), não copiada
aqui para não desatualizar — reconsultar a tabela ao vivo se for preciso
reconstruir. Recomendação: um script `docs/experiments/` ou rotina COS
com a lista de chamadas `IngestFile` (para os 7 locais) fica fácil;
os 5 externos exigiriam re-buscar e reformatar cada página à mão -
decisão de prioridade do proprietário, não bloqueante para a fase.

**Limpeza:** container `iris-guardian-clean` e volume
`iris-guardian-clean-data` removidos ao final — nada do ambiente de
verificação persiste. O container `iris-guardian` real não foi tocado,
só consultado (schema da credencial Gemini e config do `Config.MapGlobals`
para comparação).

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
| 1 | Instalação a partir de checkout limpo | Não iniciado |
| 2 | Teste formal: percurso completo | **Feito 13/09/2026** — ver §5 |
| 3 | Teste formal: falha de destino | **Refeito e corrigido 13/09/2026** — ver §5. `docs/experiments/01_falha_recuperacao_producao.md` estava desatualizado pelo roteamento por Business Rules, corrigido |
| 4 | Teste formal: falta de dados | **Feito 13/09/2026** — ver §5 |
| 5 | Teste formal: indisponibilidade de modelo/API | **Feito 13/09/2026** — formalizado como caso repetível, ver §5 |
| 6 | Auditoria de segredos | **Quase feita, 13/09/2026** — ver §4 abaixo. Nenhum segredo real encontrado em código/histórico do git. Achado de privacidade (não segredo) nos screenshots do manual: PNGs soltos e `.docx` (PT/EN) já corrigidos; falta regenerar o `.pdf` a partir do `.docx` corrigido — bloqueado numa permissão do macOS que só o proprietário aprova fisicamente |
| 7 | Fechamento de pendências no scorecard | Feito 11/09/2026 para o bônus API pública (PublicHealth), que estava implementado e testado mas não refletido em `00_MASTER_PLAN.md`/`07_SCORECARD_EVIDENCIAS.md`. Demais itens do scorecard seguem corretos |
| 8 | Gravação do vídeo | Não iniciado |
| 9 | Artigo da comunidade | Não iniciado |

## 3. Pendente

Itens 1, 8 e 9 da tabela acima (mais a regeneração do PDF do manual, ver
§4). Ver `00_MASTER_PLAN.md` §5 para o registro cronológico de
pendências e `07_SCORECARD_EVIDENCIAS.md` para evidência item a item.

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

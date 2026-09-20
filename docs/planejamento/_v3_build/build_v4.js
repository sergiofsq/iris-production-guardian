// Gera 08_ROTEIRO_GRAVACAO_VIDEO_V4.pdf com prints reais capturados ao vivo.
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const SHOTS_DIR = "/Users/sergiofernandes/Projetos/IRIS Production Guardian/docs/planejamento/screenshots";
const OUT_HTML = process.argv[2];
const OUT_PDF = process.argv[3];

// Todos os prints reais, exceto P01 (mesa de gravação física) e P25 (Finder) -
// esses dois exigem capturar a tela FÍSICA do usuário (screencapture do macOS),
// que não está disponível neste ambiente. Ficam como pendência genuína.
const REAL = {};
for (const id of ["P02","P03","P04","P05","P06","P07","P08","P09","P10","P11","P12","P13","P14","P15","P16","P17","P18","P19","P20","P21","P22","P23","P24","R1","R2"]) {
  const p = path.join(SHOTS_DIR, id + ".png");
  if (fs.existsSync(p)) REAL[id] = p;
}

const PENDING = [];

function e(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function img64(p) {
  return "data:image/png;base64," + fs.readFileSync(p).toString("base64");
}
function shot(pid, title, where, mark, note = "") {
  if (REAL[pid]) {
    const body = `<img src="${img64(REAL[pid])}">`;
    const cap = `<div class="cap real">PRINT ${pid} — ${e(title)}. ${e(note)}</div>`;
    return `<div class="shot">${body}${cap}</div>`;
  }
  PENDING.push([pid, title, where, mark]);
  return (`<div class="shot pend"><div class="ph"><div class="phid">PRINT PENDENTE ${pid}</div>` +
    `<div class="phtitle">${e(title)}</div>` +
    `<div class="phrow"><b>Tela:</b> ${e(where)}</div>` +
    `<div class="phrow"><b>Bolinha vermelha em:</b> ${e(mark)}</div></div></div>`);
}
function cmd(text, label = "Comando único (uma linha só)") {
  return `<div class="cmdlabel">${e(label)}</div><pre>${e(text)}</pre>`;
}
function say(paragraphs) {
  const ps = paragraphs.map((p) => `<p>${e(p)}</p>`).join("");
  return `<div class="say"><div class="saylabel">O QUE EU DIGO (primeira pessoa)</div>${ps}</div>`;
}
function where(kind, text) {
  const tag = { T: ["TERMINAL", "t"], G: ["GUARDIAN", "g"], P: ["PORTAL IRIS", "p"] }[kind];
  return `<div class="where"><span class="tag ${tag[1]}">${tag[0]}</span> ${text}</div>`;
}
function simple(text) { return `<div class="simple"><b>Em palavras simples:</b> ${text}</div>`; }
function warn(text) { return `<div class="warn">${text}</div>`; }
function step(n, title, ...blocks) {
  return `<div class="step"><div class="stephead"><span class="num">${n}</span>${e(title)}</div>${blocks.join("")}</div>`;
}
function section(title, sub = "") {
  const s = sub ? `<div class="sub">${e(sub)}</div>` : "";
  return `<h2>${e(title)}</h2>${s}`;
}

const parts = [];

// ------------------------------------------------------------------ CAPA
parts.push(`
<div class="cover">
  <div class="brand">IRIS PRODUCTION GUARDIAN</div>
  <h1>Roteiro de Gravação V4</h1>
  <div class="tagline">Passo a passo com prints reais, feito para quem nunca trabalhou com interoperabilidade</div>
  <div class="meta">Versão de 19/09/2026 · Prints capturados ao vivo contra a aplicação e o Management Portal reais · Login da aplicação e do Management Portal: <b>guardian / guardian</b></div>
</div>
`);

parts.push(warn(
  "<b>Estado deste arquivo (leia primeiro):</b> todos os prints são reais, capturados ao vivo contra a aplicação e o Management Portal rodando de verdade (não são mocks nem telas antigas) — " +
  "exceto <b>P01</b> (mesa de gravação com as janelas físicas do seu Mac lado a lado) e <b>P25</b> (pasta <code>entregaveis/Prompts</code> aberta no Finder), que exigem capturar a tela física do seu computador " +
  "e por isso ficam como <b>PRINT PENDENTE</b> — capture os dois manualmente (Cmd+Shift+4 no Mac) antes de considerar este documento definitivo. " +
  "Esta revisão também corrigiu 3 pontos que só apareceram testando ao vivo: (a) o print do erro #5005 exige dois cliques a mais do que o documentado antes — abrir a aba <b>Trace</b> da mensagem, clicar em <b>View Full Trace</b> e depois no losango vermelho de erro; " +
  "(b) depois de corrigir a permissão e recuperar o tráfego, os hosts <b>não</b> voltam a <code>healthy</code> na hora — <code>degraded</code> persiste por até 15 minutos após o último erro (é a própria definição do sistema), então o print de recuperação mostra 2 hosts ainda amarelos, e a fala foi ajustada para explicar isso em vez de prometer um retorno instantâneo; " +
  "(c) o diálogo \"Open\" do Rule Editor tem 3 níveis reais — <b>Guardian → Rule → IncidentRoutingRule</b> — e não \"Business Rules → Rule → IncidentRoutingRule\" como a V3 descrevia."
));

// ------------------------------------------------------------------ COMO LER
parts.push(section("Como ler este documento"));
parts.push(`
<p>Cada passo tem sempre a mesma estrutura, para você não precisar pensar:</p>
<table class="t2">
<tr><td><span class="tag t">TERMINAL</span></td><td>Você digita ou cola algo no Terminal do seu Mac. Todos os comandos aqui rodam <b>no Mac</b>, não dentro do container.</td></tr>
<tr><td><span class="tag g">GUARDIAN</span></td><td>Você clica na aplicação Production Guardian, no navegador. Depois do primeiro login, navegue <b>sempre pelo menu lateral esquerdo</b>, nunca digitando endereço.</td></tr>
<tr><td><span class="tag p">PORTAL IRIS</span></td><td>Você clica no Management Portal, o painel de administração do IRIS, em outra aba do navegador.</td></tr>
<tr><td><div class="simpleicon">Em palavras simples</div></td><td>Uma explicação sem jargão do que está acontecendo, para você entender e conseguir falar com segurança.</td></tr>
<tr><td><div class="sayicon">O que eu digo</div></td><td>A fala pronta, em primeira pessoa. Pode ler igual ou adaptar mantendo o conteúdo.</td></tr>
<tr><td><div class="shoticon">Print</div></td><td>Imagem real da tela onde você vai clicar. A <b>bolinha vermelha numerada</b> marca cada clique, na ordem.</td></tr>
</table>
<p><b>Regra dos comandos:</b> todo bloco cinza-escuro marcado como <i>"Comando único"</i> é <b>uma única linha</b>. Copie a linha inteira (mesmo que o seu terminal mostre ela quebrada em duas) e cole de uma vez. Nunca digite <code>\\</code> no fim de uma linha. Os blocos marcados como <i>"Bloco colado de uma vez"</i> têm várias linhas de propósito: cole todas juntas; o terminal só executa depois de ver a palavra <code>EOF</code> final.</p>
`);

// ------------------------------------------------------------------ GLOSSARIO
parts.push(section("Glossário para quem não conhece interoperabilidade",
  "Leia uma vez. Depois disso, nenhuma palavra do roteiro deve ser mistério."));
parts.push(`
<table class="gloss">
<tr><th>Termo</th><th>O que significa, em palavras simples</th></tr>
<tr><td><b>Interoperabilidade</b></td><td>Fazer sistemas diferentes conversarem entre si. Um sistema entrega um pedido, outro cobra, outro emite a nota. Alguém precisa levar a informação de um ao outro sem perder nada.</td></tr>
<tr><td><b>Production</b></td><td>A "linha de montagem" inteira. É o conjunto de peças que recebe, processa e entrega mensagens. O nome da nossa é <code>Guardian.Production.GuardianProduction</code>. Ela pode estar <b>Running</b> (rodando) ou parada.</td></tr>
<tr><td><b>Mensagem</b></td><td>Um pacote de informação que anda pela linha de montagem. No nosso vídeo, cada mensagem é um arquivo de texto pequeno que descreve um incidente, por exemplo "INC-003, pagamento, crítico".</td></tr>
<tr><td><b>Host</b></td><td>Uma peça da linha de montagem. Cada host faz uma tarefa. Nossa Production tem quatro (veja o quadro abaixo).</td></tr>
<tr><td><b>Service (entrada)</b></td><td>O host que <i>recebe</i> as mensagens. É a porta de entrada: fica olhando uma pasta e pega cada arquivo novo. Aqui: <code>FileIncidentService</code>.</td></tr>
<tr><td><b>Process (processamento)</b></td><td>O host que <i>decide</i> para onde a mensagem vai. Aqui: <code>IncidentRouterProcess</code>, que lê a gravidade do incidente e escolhe o destino.</td></tr>
<tr><td><b>Operation (saída)</b></td><td>O host que <i>entrega</i> a mensagem no destino final, gravando um arquivo numa pasta. Temos dois: <code>FileOutputOperation</code> (incidentes comuns) e <code>PriorityOutputOperation</code> (incidentes graves).</td></tr>
<tr><td><b>Fila</b></td><td>Mensagens esperando a vez de um host. Fila zerada é sinal de que tudo está fluindo.</td></tr>
<tr><td><b>Severidade</b></td><td>A gravidade do incidente: <code>LOW</code> (baixa), <code>MEDIUM</code> (média), <code>HIGH</code> (alta), <code>CRITICAL</code> (crítica).</td></tr>
<tr><td><b>Healthy / Degraded / Unavailable</b></td><td>Saudável (verde), degradado (amarelo: funciona com problema) e indisponível (vermelho: fora do ar). <b>Importante (achado ao vivo nesta revisão):</b> um host fica <code>degraded</code> por até <b>15 minutos</b> depois do último erro registrado, mesmo que o tráfego novo já esteja passando sem problema — não é um bug, é a própria janela de observação do sistema.</td></tr>
<tr><td><b>Management Portal</b></td><td>O painel de administração do IRIS. Aqui você enxerga a Production "por dentro", inclusive cada mensagem que passou por ela.</td></tr>
<tr><td><b>Message Viewer</b></td><td>A tela do Management Portal que lista todas as mensagens, com horário, origem, destino e se deu erro. É a "prova real" do tráfego.</td></tr>
<tr><td><b>Business Rule</b></td><td>Uma regra de negócio configurada visualmente, sem programar. A nossa decide: gravidade alta, crítica ou média vai para o destino prioritário; o resto vai para o destino normal.</td></tr>
<tr><td><b>IA / RAG</b></td><td>RAG é uma IA que responde consultando a documentação do próprio projeto e citando a fonte. Se não achar nada relevante, ela diz que não sabe em vez de inventar.</td></tr>
</table>

<div class="diagram">
  <div class="dtitle">Como a nossa linha de montagem funciona (o que vai aparecer no Monitor)</div>
  <div class="flow">
    <div class="box in">ENTRADA<br><b>FileIncidentService</b><br><span>pega o arquivo novo na pasta <code>in</code></span></div>
    <div class="arrow">&rarr;</div>
    <div class="box pr">DECISÃO<br><b>IncidentRouterProcess</b><br><span>lê a gravidade e escolhe o destino</span></div>
    <div class="arrow">&rarr;</div>
    <div class="fork">
      <div class="box ok">SAÍDA NORMAL (LOW)<br><b>FileOutputOperation</b><br><span>grava em <code>out</code></span></div>
      <div class="box pri">SAÍDA PRIORITÁRIA (MEDIUM, HIGH, CRITICAL)<br><b>PriorityOutputOperation</b><br><span>grava em <code>out_priority</code></span></div>
    </div>
  </div>
  <div class="dnote">Na falha controlada, vamos bloquear a pasta <code>out_priority</code>. Só o caminho de baixo (prioritário) vai reclamar. O caminho normal continua verde.</div>
</div>
`);

// ------------------------------------------------------------------ MAPA DE JANELAS
parts.push(section("Monte sua mesa de gravação antes de começar",
  "Quatro janelas abertas, cada uma com um papel fixo."));
parts.push(`
<table class="t3">
<tr><th>Janela</th><th>Para que serve</th><th>Fica aberta</th></tr>
<tr><td><b>Terminal 1</b> (Mac)</td><td>Comandos pontuais: iniciar, quebrar e consertar o destino, disparar incidentes.</td><td>O vídeo inteiro</td></tr>
<tr><td><b>Terminal 2</b> (Mac, ao lado)</td><td>Só o loop de tráfego contínuo (seção 2). Fica rodando para o Monitor parecer uma produção viva.</td><td>Da seção 2 até a limpeza</td></tr>
<tr><td><b>Navegador, aba 1: Guardian</b></td><td>Monitor, Investigator e os dois RAG Assistants.</td><td>O vídeo inteiro</td></tr>
<tr><td><b>Navegador, aba 2: Management Portal</b></td><td>Message Viewer e Business Rule Editor.</td><td>Abrir na seção 3</td></tr>
</table>
` + shot("P01", "Mesa de gravação pronta: Terminal 1, Terminal 2 lado a lado e navegador",
  "Tela inteira do Mac com as janelas dispostas como no vídeo",
  "(1) Terminal 1, (2) Terminal 2, (3) navegador com a aba do Guardian"));

// ------------------------------------------------------------------ SECAO 0
parts.push('<div class="pagebreak"></div>');
parts.push(section("0. Antes de gravar", "Faça esta lista uma vez, na ordem. Nada aqui vai para o vídeo."));
parts.push(
  step("0.1", "Esconder tudo que é pessoal",
    where("G", "No navegador, feche todas as abas que não sejam do vídeo e <b>oculte a barra de favoritos</b> (no Chrome: Cmd+Shift+B). Prints antigos deste projeto já vazaram a barra de favoritos sem querer. Se preferir, use uma janela anônima."),
    warn("<b>Nunca abra a tela de credenciais</b> (Interoperability → Configure → Credentials). É lá que ficam as chaves de API do Gemini e do Groq. Se você não abrir essa tela, está seguro.")),
  step("0.2", "Ligar o container do IRIS",
    where("T", "No Terminal 1:"),
    cmd("docker start iris-guardian"),
    simple("O container é um \"computador dentro do computador\" onde o IRIS roda. Este comando liga ele.")),
  step("0.3", "Conferir se a Production está rodando",
    where("T", "No Terminal 1, cole as 5 linhas de uma vez, do <code>docker exec</code> até o <code>EOF</code>:"),
    cmd(`docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
write ##class(Ens.Director).GetProductionStatus(.tName,.tState),!
write "Nome: ",tName," Estado: ",tState,!
halt
EOF`, "Bloco colado de uma vez (várias linhas de propósito)"),
    simple("Você deve ver <code>Estado: 1</code>. O número 1 significa Running (rodando)."),
    where("T", "Se o estado <b>não</b> for 1, cole este bloco e confira de novo. Não passe o nome da Production para <code>RecoverProduction()</code>; isso dá erro <code>&lt;PARAMETER&gt;</code>:"),
    cmd(`docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
set sc=##class(Ens.Director).RecoverProduction()
write "Recover sc: ",sc,!
set sc=##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
write "Start sc: ",sc,!
halt
EOF`, "Bloco colado de uma vez (várias linhas de propósito)"),
    shot("P02", "Terminal 1 mostrando o resultado do comando: Estado: 1",
      "Terminal 1 do Mac após colar o bloco de conferência", "(1) linha \"Nome: Guardian.Production.GuardianProduction Estado: 1\"")),
  step("0.4", "Limpar as pastas de mensagens",
    where("T", "No Terminal 1:"),
    cmd("docker exec -i iris-guardian sh -c 'D=/durable/guardian; rm -f $D/in/* $D/archive/* $D/out/* $D/out_priority/* && chmod 755 $D/out $D/out_priority'"),
    simple("Apaga os arquivos de testes anteriores para o vídeo começar do zero e garante que as pastas de saída aceitam gravação.")),
  step("0.5", "Refresh forçado e idioma em inglês",
    where("G", "No navegador, abra <code>http://localhost:53773/csp/guardian/Guardian.UI.MonitorPage.cls</code> (é a <b>única</b> URL de página que você digita na gravação inteira). Faça login com <b>guardian / guardian</b> e dê um refresh forçado: <b>Cmd+Shift+R</b>."),
    where("G", "No <b>canto superior da barra lateral</b>, clique no botão de idioma até aparecer <b>EN</b>. O concurso exige interface em inglês na gravação. Confira que o título da aba do navegador também ficou em inglês em cada página que abrir."),
    shot("P03", "Barra lateral do Guardian com o botão de idioma em EN",
      "Guardian, canto superior esquerdo da barra lateral", "(1) botão de idioma")),
  step("0.6", "Ensaio completo sem gravar",
    "<p>Faça o vídeo inteiro uma vez, cronometrando, sem gravar. Corrija qualquer trava antes da tomada real. Decida também se vai narrar ao vivo ou legendar depois: cada passo já tem a fala pronta.</p>")
);

// ------------------------------------------------------------------ SECAO 1
parts.push('<div class="pagebreak"></div>');
parts.push(section("1. Abertura (30 a 60 segundos)", "Tela parada, sem clicar em nada."));
parts.push(step("1.1", "Mostrar a aplicação e falar",
  where("G", "Deixe o navegador na tela do <b>Production Monitor</b>, já logado, sem navegar. Se preferir, mostre antes o slide de abertura (item 1.2)."),
  simple("Você está apresentando três ferramentas dentro de um mesmo produto: uma que <i>mostra</i> a saúde da linha de montagem, uma que <i>investiga</i> falhas com IA, e uma que <i>responde perguntas</i> sobre a documentação."),
  say([
    "Este é o IRIS Production Guardian, uma aplicação que construí inteiramente sobre a plataforma InterSystems IRIS para resolver um problema real de operação: quando algo falha num ambiente de integração, alguém precisa entender o que aconteceu, rápido, e não pode simplesmente confiar numa resposta genérica.",
    "A aplicação tem três módulos. O primeiro é o Production Monitor, que mostra em tempo real o estado de cada host da produção, se está saudável, degradado ou fora do ar, e quantas mensagens estão passando por cada um.",
    "O segundo é o AI Incident Investigator. Quando um componente falha, eu seleciono o componente e uma janela de tempo, e a IA analisa os dados reais da falha e monta uma investigação estruturada: o que os dados mostram, qual é a hipótese mais provável da causa, e o que não dá para afirmar com certeza. Ela nunca corrige nada sozinha, a decisão de agir continua sendo minha.",
    "O terceiro é o RAG Assistant, que responde perguntas sobre a documentação do próprio projeto citando a fonte real, e se recusa a responder quando não tem informação suficiente, em vez de inventar uma resposta. Implementei duas versões, uma com Gemini e outra com Groq, para mostrar que a arquitetura funciona com mais de um provedor de IA.",
    "Tudo isso roda sobre o InterSystems IRIS: a produção de interoperabilidade, o armazenamento vetorial da busca híbrida, e a orquestração dos três módulos."]),
  shot("P04", "Guardian na tela inicial (Production Monitor), estado saudável, idioma EN",
    "Guardian, item MONITOR selecionado na barra lateral", "(1) item Monitor da barra lateral, (2) linha \"State: Running\", (3) badges healthy nos quatro hosts")));
parts.push(step("1.2", "Slide de abertura (opcional)",
  "<p>Se quiser um slide em vez da aplicação parada, cole o prompt abaixo numa IA geradora de imagem (Gemini, ChatGPT, Ideogram). Ele usa as cores reais da aplicação.</p>" +
  '<pre class="prompt">' + e(`Design a single widescreen (16:9, 1920x1080) title slide for the opening of a product demo video called "IRIS Production Guardian", built on InterSystems IRIS. Style: clean, modern, minimal enterprise SaaS dashboard aesthetic, flat design, soft shadows, rounded rectangles, no photorealism, no stock-photo people, no watermarks.

Color palette (use exactly these hex values):
- Primary background: deep navy blue gradient from #0A1965 to #102F8B.
- Accent / highlight color: teal #01989C and cyan #0FD1C4.
- Card surfaces: white #FFFFFF.
- Secondary surface: light gray #F0F3F9.
- Title text: white. Subtitle text: teal #0FD1C4.

Layout: a horizontal BPM-style flow of 3 connected rounded rectangle cards, left to right, connected by thin teal arrows, on the navy gradient background. Each card has a simple line icon at the top and a label + short sublabel below:
- Card 1 - icon: pulse/heartbeat monitor - label "Production Monitor" - sublabel "Real-time health of every host".
- Card 2 - icon: magnifying glass over a warning triangle - label "AI Incident Investigator" - sublabel "Evidence-based root-cause analysis".
- Card 3 - icon: chat bubble with a document - label "RAG Assistant" - sublabel "Cited answers from the project's own docs".

Above the flow: bold white title "IRIS Production Guardian", with a smaller teal subtitle underneath: "Built entirely on InterSystems IRIS". Keep all text minimal and legible at video-thumbnail distance. Export as a single flat image, no borders.`) + "</pre>"));

// ------------------------------------------------------------------ SECAO 2
parts.push('<div class="pagebreak"></div>');
parts.push(section("2. Production saudável, com mensagens passando em tempo real (1 a 2 minutos)",
  'Objetivo: mostrar como é o "normal", para o público perceber a diferença quando algo quebrar.'));
parts.push(step("2.1", "Mostrar o Monitor saudável",
  where("G", "Na aba do Guardian, clique em <b>Monitor</b> no menu lateral esquerdo."),
  simple("O Monitor é um painel que se atualiza sozinho a cada 10 segundos. Cada cartão é um host. Verde com a palavra <b>healthy</b> significa: sem fila parada e sem erro recente."),
  "<p>Aponte com o mouse para: <b>State: Running</b>, os quatro cartões com badge <b>healthy</b> e o horário de coleta.</p>",
  shot("P05", "Production Monitor saudável: State Running, quatro hosts healthy",
    "Guardian, MONITOR", "(1) item Monitor no menu lateral, (2) \"State: Running\", (3) badge healthy de um host, (4) horário de coleta")));
parts.push(step("2.2", "Ligar o tráfego contínuo",
  where("T", "Abra o <b>Terminal 2</b> (a janela ao lado). Ele vai mandar uma mensagem de baixa gravidade (<code>LOW</code>) a cada 6 segundos. Cole o bloco inteiro de uma vez; ele é um script completo."),
  cmd(`I=0
DIR=/durable/guardian/in
while true; do
  I=$((I + 1))
  ID="LOOP-$(date +%H%M%S)-${"${I}"}"
  FILE="$DIR/loop_${"${I}"}.txt"
  MSG="${"${ID}"}|IRIS.Service.OrderIngest|LOW|Trafego continuo de demonstracao #${"${I}"}"
  docker exec -i iris-guardian sh -c "echo '$MSG' > $FILE && chown irisowner:irisowner $FILE"
  echo "[$(date +%T)] enviado ${"${ID}"}"
  sleep 6
done`, "Script inteiro, cole tudo de uma vez"),
  "<p><b>Alternativa mais segura</b> (mesmo resultado, sem risco de colagem quebrada), no Terminal 2, dentro da pasta do projeto:</p>" + cmd("sh docs/experiments/loop_trafego_saudavel.sh", "Comando único") +
  "<p>Para mudar o intervalo para 10 segundos: <code>sh docs/experiments/loop_trafego_saudavel.sh 10</code>.</p>",
  simple('Cada arquivo criado na pasta <code>in</code> é uma mensagem entrando na linha de montagem. Você vai ver no Terminal 2 uma linha nova a cada 6 segundos dizendo "enviado LOOP-...". Deixe rodando <b>até a limpeza, no final</b>; só pare com Ctrl+C lá.'),
  shot("P06", 'Terminal 2 com o loop rodando, linhas "enviado LOOP-..."',
    "Terminal 2 do Mac", '(1) linhas "[hh:mm:ss] enviado LOOP-..." aparecendo a cada 6 segundos')));
parts.push(step("2.3", "Mostrar que o tráfego é real",
  where("G", "Volte ao <b>Monitor</b> e aponte o horário de coleta e os contadores de <b>Mensagens</b> subindo a cada poucos segundos."),
  "<p>Opcional, para provar que são arquivos de verdade chegando e não algo simulado na tela:</p>",
  where("T", "No Terminal 1:"),
  cmd("docker exec -i iris-guardian ls -la /durable/guardian/out", "Comando único"),
  say(["Aqui está o estado saudável, com tráfego real entrando continuamente. Vou guardar essa imagem para comparar depois da falha."]),
  shot("P07", "Monitor com contadores de mensagens aumentando (compare dois momentos)",
    "Guardian, MONITOR", '(1) contador "Mensagens" de um host, (2) horário de coleta'),
  shot("P08", "Terminal 1 listando a pasta out com os arquivos chegando",
    "Terminal 1 do Mac", "(1) lista de arquivos loop_*.txt / incident_*.txt")));
parts.push(step("2.4", "Mostrar o tráfego por dentro, no painel de administração do IRIS",
  where("P", "Abra uma <b>nova aba</b> e digite <code>http://localhost:53773/csp/sys/UtilHome.csp</code>. Entre com <b>guardian / guardian</b> se pedir."),
  where("P", "No menu esquerdo, clique em <b>Interoperability</b> (1) → <b>View</b> (2) → <b>Messages</b> (3)."),
  simple('Message Viewer é uma tabela com uma linha para cada mensagem que passou pela Production. Cada linha mostra a hora, quem enviou (<b>Source</b>), quem recebeu (<b>Target</b>) e o status. É a "nota fiscal" de tudo o que aconteceu.'),
  shot("P09", "Management Portal, menu Interoperability → View → Messages",
    "Management Portal, home", "(1) Interoperability no menu esquerdo, (2) View, (3) Messages"),
  shot("P10", "Message Viewer listando as mensagens LOOP-... com Status Completed",
    "Management Portal → Interoperability → View → Messages", "(1) coluna Source, (2) coluna Target, (3) coluna Status, (4) botão de atualizar a lista"),
  say(["Este é o painel de administração do IRIS. Aqui eu vejo cada mensagem que atravessou a produção: de onde veio, para onde foi e se terminou bem. Repare que as mensagens do meu tráfego contínuo estão todas concluídas, sem erro."])));

// ------------------------------------------------------------------ SECAO 3
parts.push('<div class="pagebreak"></div>');
parts.push(section("3. Introduzir a falha controlada (2 a 3 minutos)",
  "Vamos quebrar de verdade um dos destinos e ver o sistema reagir."));
parts.push(step("3.1", "Bloquear o destino prioritário",
  where("T", "No Terminal 1:"),
  cmd("docker exec -i iris-guardian chmod 555 /durable/guardian/out_priority"),
  simple("<code>chmod 555</code> tira a permissão de gravar na pasta <code>out_priority</code>. É como trancar a porta do destino. A pasta continua existindo, mas ninguém consegue escrever nela. Isso simula um disco cheio, uma permissão negada ou uma rede fora do ar. Não mexemos em nada dentro do IRIS."),
  say(["Estou removendo a permissão de escrita do diretório de saída usado por incidentes críticos. Isso simula um destino indisponível de verdade, não uma falha fingida na interface."]),
  shot("P11", "Terminal 1 depois do chmod 555 (sem mensagem de erro é normal)",
    "Terminal 1 do Mac", "(1) o comando docker exec ... chmod 555 executado")));
parts.push(step("3.2", "Disparar um incidente grave",
  where("T", "No Terminal 1. Este é <b>um comando só</b>, colado inteiro, em uma linha:"),
  cmd(`docker exec -i iris-guardian sh -c 'F=/durable/guardian/in/demo3.txt; echo "INC-003|IRIS.Service.PaymentGateway|CRITICAL|Falha de escrita simulada no destino" > $F && chown irisowner:irisowner $F'`),
  simple("Este comando faz três coisas encadeadas dentro de <b>um único</b> comando: (a) guarda o caminho do arquivo numa variável <code>$F</code>; (b) cria o arquivo com o incidente <code>INC-003</code> de severidade <code>CRITICAL</code>; (c) entrega a posse do arquivo ao usuário do IRIS (<code>chown</code>). Você <b>não</b> precisa rodar cada parte separada."),
  "<p>Como é <code>CRITICAL</code>, a regra de negócio vai mandar esta mensagem para o destino prioritário, justamente a pasta que acabamos de trancar.</p>"));
parts.push(step("3.3", "Ver a falha aparecer no Monitor (espere ao vivo)",
  where("G", "Volte à aba do Guardian e clique em <b>Monitor</b> no menu lateral esquerdo. <b>Espere de 15 a 20 segundos, ao vivo</b>, sem cortar o vídeo. Esse tempo é real: é o tempo que o IRIS insiste em tentar antes de desistir (<code>FailureTimeout</code>)."),
  say([
    "Repare na lista de hosts do Monitor: cada linha é um componente que processa mensagens dentro da produção. Duas delas, o FileIncidentService, que recebe os arquivos de incidente, e o FileOutputOperation, que escreve as saídas normais, continuam verdes, ou seja, saudáveis, processando normalmente, porque o tráfego contínuo do loop que deixei rodando não usa o destino que acabei de bloquear.",
    "As outras duas mudaram de cor, de verde para amarelo: o IncidentRouterProcess, que é o componente que decide para onde cada incidente deve ir, e principalmente o PriorityOutputOperation, que é exatamente o componente que tentou escrever no diretório que eu bloqueei no passo anterior. Amarelo aqui significa degraded, degradado, não fora do ar.",
    "O que isso mostra na prática é que a falha é isolada: ela não derrubou a aplicação inteira, só o caminho específico que estava tentando escrever no destino problemático. O tráfego normal, que passa pelo caminho verde, nem percebeu que algo deu errado, e isso vai ficar ainda mais claro no próximo passo, olhando os contadores."]),
  "<p>Enquanto isso, o Terminal 2 segue enviando mensagens normais. Aponte que os contadores do <code>FileOutputOperation</code> continuam subindo, enquanto só a saída prioritária degrada.</p>",
  shot("P12", "Monitor com FileIncidentService e FileOutputOperation verdes, IncidentRouterProcess e PriorityOutputOperation amarelos (degraded)",
    "Guardian, MONITOR", "(1) cartão amarelo PriorityOutputOperation, (2) cartão amarelo IncidentRouterProcess, (3) cartões verdes FileIncidentService e FileOutputOperation")));
parts.push(step("3.4", "Provar que o erro é real: Message Viewer e o trace completo",
  where("P", "Volte à aba do Management Portal. Menu esquerdo: <b>Interoperability</b> → <b>View</b> → <b>Messages</b>."),
  simple("A mensagem mais recente vai aparecer com <b>Status = Error</b> (é o INC-003 — o número de ID interno do IRIS é diferente do texto \"INC-003\" que está dentro do arquivo, isso é normal)."),
  shot("P13", "Message Viewer com a mensagem do INC-003 em Status Error (linha do topo)",
    "Management Portal → Interoperability → View → Messages", "(1) linha do topo com status Error"),
  warn("<b>Achado ao vivo nesta revisão:</b> clicar na linha só abre o cabeçalho da sessão (aba <b>Header</b>), que <b>não</b> mostra o texto do erro #5005 diretamente — o <code>ErrorStatus</code> ali aparece como \"OK\" porque é o registro do envio original, não da tentativa que falhou. Para ver o texto real do erro, clique na mensagem, depois na aba <b>Trace</b>, depois em <b>View Full Trace</b> (abre uma janela nova) e clique no <b>losango vermelho</b> que aparece na coluna Operations — aí sim aparece o texto completo do erro."),
  shot("P14", "Detalhe do losango de erro no Trace completo, mostrando o texto do ERROR #5005",
    "Message Viewer → clicar na mensagem → aba Trace → View Full Trace → clicar no losango vermelho", "(o losango vermelho de erro, na coluna Operations)"),
  say(["Aqui a falha é real, não simulada na interface. O processo tentou escrever e o sistema operacional recusou."]),
  "<p><b>Alternativa por comando</b> (só se quiser mostrar em terminal; anote o <code>ID</code> da mensagem com erro, você vai precisar dele na seção 6). Cole as 6 linhas de uma vez:</p>",
  cmd(`docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
set st=##class(%SQL.Statement).%New()
set sc=st.%Prepare("SELECT ID,TargetConfigName,Status,ErrorStatus FROM Ens.MessageHeader ORDER BY ID DESC")
set rs=st.%Execute()
do rs.%Display()
halt
EOF`, "Bloco colado de uma vez (várias linhas de propósito)")));

// ------------------------------------------------------------------ SECAO 4
parts.push('<div class="pagebreak"></div>');
parts.push(section("4. AI Incident Investigator (2 a 3 minutos)",
  "A IA olha os dados reais da falha e monta uma investigação. Só lê, nunca corrige."));
parts.push(step("4.1", "Abrir o Investigator e escolher o problema",
  where("G", "No menu lateral esquerdo, clique em <b>Investigator</b>."),
  where("G", "No campo <b>Component</b>, escolha <code>Guardian.Operation.PriorityOutputOperation</code>. No campo <b>Window (minutes)</b>, deixe <b>60</b>."),
  simple('Você está dizendo à IA: "olhe este componente, nos últimos 60 minutos". Uma janela de 60 minutos cobre com folga o momento da falha.'),
  shot("P15", "Investigator com o componente PriorityOutputOperation selecionado e janela 60",
    "Guardian, INVESTIGATOR", "(1) item Investigator no menu, (2) campo Component, (3) campo Window, (4) botão Investigate")));
parts.push(step("4.2", "Rodar a investigação",
  where("G", "Clique em <b>Investigate</b>. A tela escurece com o logo do Production Guardian e um círculo girando. <b>Isso é normal, não é travamento.</b> Deixe o vídeo rolando durante toda a espera."),
  say(["A IA está analisando agora, em tempo real, os dados reais da falha."]),
  shot("P16", "Overlay de carregamento (logo + spinner) durante a análise",
    "Guardian, INVESTIGATOR, após clicar em Investigate", "(1) botão Investigate clicado, (2) spinner central"),
  warn("Se a IA (Gemini) devolver um erro transitório de sobrecarga (HTTP 503), a tela mostra isso de forma honesta em vez de travar ou inventar uma análise — clique em Investigate de novo em alguns segundos. Isso realmente aconteceu numa das tentativas desta revisão.")));
parts.push(step("4.3", "Ler o resultado para a câmera",
  "<p>Leia em voz alta as partes, uma a uma. É o ponto mais importante do vídeo:</p>" +
  "<ul><li><b>Summary</b>: resumo de uma linha do que aconteceu.</li><li><b>Observations</b>: o que os dados mostram.</li><li><b>Hypotheses</b>: a causa mais provável.</li><li><b>Gaps</b>: o que <i>não</i> dá para afirmar com os dados disponíveis.</li><li><b>Suggested next steps</b>: o que fazer a seguir — sugestão, não ação automática.</li></ul>",
  warn('Não clique em nada que pareça "corrigir automaticamente". Esse botão não existe, e a fala deve deixar claro que a decisão de corrigir é humana.'),
  say(["Repare que a IA separa o que os dados mostram, que é a observação, do que ela supõe, que é a hipótese, e do que ela não consegue afirmar, que são as lacunas. Ela também sugere os próximos passos, mas não faz nada sozinha. A decisão de agir é minha."]),
  shot("P17", "Resultado da investigação: Summary, Observations, Hypotheses, Gaps e Suggested next steps",
    "Guardian, INVESTIGATOR, após a análise", "(1) bloco Summary, (2) bloco Observations, (3) bloco Hypotheses, (4) bloco Gaps")));

// ------------------------------------------------------------------ SECAO 5
parts.push(section("5. Perguntar aos dois RAG Assistants (3 a 4 minutos)",
  "Use exatamente estas perguntas. Elas foram testadas contra o conteúdo real do projeto."));
parts.push(simple("O RAG Assistant só responde com base na documentação do projeto e mostra de onde tirou. Se a pergunta não tem nada a ver com a documentação, ele deve dizer que não sabe. Isso se chama <b>abstenção</b>. O corte é uma similaridade de 0.58: perguntas relevantes ficam acima disso; perguntas fora do assunto, abaixo."));
parts.push(step("5.1", "Gemini: pergunta com resposta na documentação",
  where("G", "Clique em <b>RAG Assistant (Gemini)</b> no menu lateral esquerdo. Digite a pergunta abaixo e clique em <b>Ask</b> (a tela escurece de novo até a resposta chegar; é normal)."),
  "<blockquote>Qual a causa do erro #5005?</blockquote>",
  simple("Esperado: uma resposta que cita um documento real do projeto e liga ao erro que você acabou de gerar. <b>Clique na fonte citada</b> para mostrar que ela existe e não foi inventada."),
  shot("P18", "RAG Assistant (Gemini) com a resposta e a fonte citada",
    "Guardian, RAG ASSISTANT (GEMINI)", "(1) item RAG Assistant (Gemini) no menu, (2) caixa da pergunta, (3) botão Ask, (4) fonte citada na resposta")));
parts.push(step("5.2", "Gemini: pergunta fora do assunto (abstenção)",
  where("G", "Ainda no RAG Assistant (Gemini), pergunte:"),
  "<blockquote>Qual a receita de bolo de chocolate?</blockquote>",
  simple("Esperado: o sistema diz que não sabe (similaridade abaixo do corte de 0.58). <b>Ele não deve inventar uma receita.</b>"),
  say(["Aqui o sistema se recusa a responder porque não há nada no conteúdo indexado sobre isso. Isso é a abstenção calibrada, não é um bug."]),
  shot("P19", "RAG Assistant recusando a pergunta sobre bolo de chocolate",
    "Guardian, RAG ASSISTANT (GEMINI)", '(1) resposta "não sei / sem informação suficiente"')));
parts.push(step("5.3", "Groq: mesma pergunta 1, outro provedor de IA",
  where("G", "Clique em <b>RAG Assistant (Groq)</b> no menu lateral esquerdo e repita: <i>Qual a causa do erro #5005?</i>"),
  say(["Este é o segundo provedor. A busca e os embeddings são os mesmos, do Gemini, e só o modelo que escreve a resposta muda: aqui é o openai/gpt-oss-120b, servido pelo Groq. A resposta também vem com citação de fonte."]),
  shot("P20", "RAG Assistant (Groq) respondendo com citação de fonte",
    "Guardian, RAG ASSISTANT (GROQ)", "(1) item RAG Assistant (Groq) no menu, (2) resposta, (3) fonte citada"),
  warn("Se alguma resposta não repetir o esperado no dia (por exemplo, se o conteúdo indexado mudou), <b>não invente</b>: grave o resultado real e ajuste a fala, nunca a tela.")));

// ------------------------------------------------------------------ SECAO 6
parts.push('<div class="pagebreak"></div>');
parts.push(section("6. Consertar o destino e mostrar a recuperação (2 minutos)"));
parts.push(step("6.1", "Destrancar a pasta",
  where("T", "No Terminal 1:"),
  cmd("docker exec -i iris-guardian chmod 755 /durable/guardian/out_priority"),
  simple("<code>chmod 755</code> devolve a permissão de gravar. É o conserto do problema que criamos.")));
parts.push(step("6.2", "Mostrar que tráfego novo passa",
  where("T", "No Terminal 1. Comando único, uma linha só:"),
  cmd(`docker exec -i iris-guardian sh -c 'F=/durable/guardian/in/demo4.txt; echo "INC-004|IRIS.Service.PaymentGateway|LOW|Fluxo normal apos recuperacao do destino" > $F && chown irisowner:irisowner $F'`),
  simple("Mesmo formato do passo 3.2: cria o arquivo <code>demo4.txt</code> e entrega a posse ao IRIS, tudo em <b>um comando só</b>."),
  where("G", "Espere cerca de 15 segundos e clique em <b>Monitor</b> no menu lateral esquerdo."),
  warn("<b>Achado ao vivo nesta revisão — importante para a fala:</b> os hosts <b>não</b> voltam a <code>healthy</code> na hora, mesmo com o INC-004 passando sem erro. <code>degraded</code> significa \"fila pendente <b>ou erro nos últimos 900 segundos (15 minutos)</b>\" — é a própria definição do sistema, visível no rodapé do Monitor. Então o print abaixo mostra, de propósito, o <code>IncidentRouterProcess</code> e o <code>PriorityOutputOperation</code> ainda amarelos, só que agora com o contador de mensagens subindo normalmente — é exatamente essa distinção (degradado mas processando) que vale narrar."),
  say(["O sistema aceita e processa o tráfego novo imediatamente, sem reiniciar nada — repare que os contadores de mensagem sobem normalmente. O status ainda mostra degraded, e é assim mesmo: a definição de degraded aqui inclui qualquer erro nos últimos 15 minutos, então o indicador visual demora a limpar mesmo depois da causa já ter sido corrigida. É uma escolha de design que favorece não esconder um problema recente rápido demais."]),
  shot("P21", "Monitor após a recuperação: tráfego novo passando, degraded ainda visível por até 15 min (comportamento real, não bug)",
    "Guardian, MONITOR", "(1) contador de Mensagens do PriorityOutputOperation subindo, (2) badge degraded ainda visível")));
parts.push(step("6.3", "Explicar por que o INC-003 não some sozinho",
  simple("A mensagem <code>INC-003</code> falhou <b>antes</b> de a pasta ser consertada. O tempo de tentativas já tinha acabado, então essa mensagem específica ficou marcada como falha. Isso é o comportamento normal do IRIS. Mensagens <b>novas</b> passam normalmente, sem reiniciar nada."),
  "<p><b>Reenvio manual (opcional).</b> Duas formas:</p>",
  where("P", "<b>Pelo Message Viewer</b> (mais fácil para gravar): Management Portal → <b>Interoperability</b> → <b>View</b> → <b>Messages</b> → marque a caixinha da mensagem do INC-003 com erro → clique em <b>Resend</b>."),
  shot("P22", "Message Viewer com a mensagem do INC-003 marcada e o botão Resend em destaque",
    "Management Portal → Interoperability → View → Messages", "(1) checkbox da linha marcada, (2) botão Resend"),
  where("T", "<b>Por comando</b>: troque <code>&lt;ID_DA_MENSAGEM&gt;</code> pelo número anotado no passo 3.4 e cole as 4 linhas de uma vez:"),
  cmd(`docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
set sc=##class(Ens.MessageHeader).ResendMessage(<ID_DA_MENSAGEM>)
write "Resend sc: ",sc,!
halt
EOF`, "Bloco colado de uma vez (várias linhas de propósito)"),
  "<p>Confirme o arquivo <code>incident_INC-003.txt</code> aparecendo em <code>out_priority</code>.</p>",
  say(["O sistema se recupera sozinho para tráfego novo, sem reiniciar nada, e nada foi escondido ou fingido como sucesso enquanto a mensagem antiga continuava marcada como falha."])));

// ------------------------------------------------------------------ SECAO 7
parts.push('<div class="pagebreak"></div>');
parts.push(section("7. Bônus implementados (2 a 3 minutos)"));
parts.push(step("7.1", "Business Rules: quem decide para onde vai cada incidente",
  simple('Uma <b>regra de negócio</b> é uma decisão do tipo "se acontecer isto, faça aquilo" que você edita <b>visualmente</b>, sem programar e sem recompilar o resto do sistema. A nossa lê a severidade e escolhe o destino.'),
  warn("<b>O endereço direto da regra não carrega o diagrama sozinho.</b> Ele só preenche o nome na barra de navegação; a área de edição fica vazia até você clicar em <b>Open</b>. Por isso, siga os cliques abaixo."),
  where("P", "No Management Portal, clique em <b>Interoperability</b> (1) no menu esquerdo, depois em <b>Build</b> (2), depois em <b>Business Rules</b> (3)."),
  shot("R1", "Caminho de cliques: Interoperability (1) → Build (2) → Business Rules (3), Production Running",
    "", ""),
  where("P", "Abre o Rule Editor vazio. Clique no botão <b>Open</b> no canto superior direito da tela."),
  shot("P23", "Rule Editor vazio com o botão Open em destaque",
    "Management Portal → Interoperability → Build → Business Rules", "(1) botão Open"),
  where("P", "No diálogo <b>Open Rule</b>, clique em <b>Guardian</b> (nome do pacote) → depois em <b>Rule</b> → depois em <b>IncidentRoutingRule</b>."),
  warn("<b>Achado ao vivo nesta revisão:</b> o primeiro nível do diálogo é o nome do pacote (<b>Guardian</b>), não \"Business Rules\" — a V3 anterior descrevia esse clique errado."),
  shot("P24", "Diálogo Open com o caminho Rule → IncidentRoutingRule (já dentro do pacote Guardian)",
    "Rule Editor, diálogo Open", "(1) pasta Rule, (2) IncidentRoutingRule"),
  "<p>A regra carrega assim:</p>",
  shot("R2", "Regra RouteBySeverity carregada",
    "", "", "Se Severity for HIGH, CRITICAL ou MEDIUM, devolve PriorityOutputOperation; caso contrário (otherwise), devolve FileOutputOperation."),
  say([
    "Este é o Business Rules Editor do IRIS, um editor visual de regras de negócio. A regra que estou mostrando, RouteBySeverity, é a que decide para onde cada incidente vai: se a severidade for HIGH, CRITICAL ou MEDIUM, a regra devolve o nome do Guardian.Operation.PriorityOutputOperation, o destino prioritário que acabei de testar na falha controlada. Para qualquer outra severidade, ela devolve o Guardian.Operation.FileOutputOperation, o destino normal.",
    "O ponto importante aqui é que essa decisão de roteamento é configurável visualmente, sem recompilar nada. Se eu quisesse adicionar uma quarta severidade ou trocar o destino, eu editaria essa regra aqui e recompilaria só ela, sem tocar no código dos outros componentes. É exatamente essa regra que decidiu, nas seções 3 e 6, mandar o INC-003 e o INC-004 para destinos diferentes."])));
parts.push(step("7.2", "Busca híbrida (só falar, sem clicar)",
  simple("Você não clica em nada. Só explica como o RAG Assistant achou os trechos certos em todas as perguntas da seção 5. <b>Vetorial</b> = busca por significado. <b>Lexical</b> = busca por palavra exata. Juntar as duas dá resultado melhor que qualquer uma sozinha."),
  say([
    "A busca do RAG Assistant não usa só uma técnica, ela combina duas. A primeira é busca vetorial: a pergunta do usuário é transformada num vetor numérico, um embedding, e comparada por similaridade com o vetor de cada trecho da documentação. Isso captura o significado da pergunta, mesmo que as palavras exatas sejam diferentes das do documento. A segunda é busca lexical, usando o índice de texto completo nativo do IRIS, o iFind. Isso captura correspondências exatas de palavras-chave, que a busca por significado às vezes não prioriza.",
    "Os dois rankings são combinados por um método chamado Reciprocal Rank Fusion: cada busca contribui com até 15 candidatos, e a posição de cada trecho nos dois rankings é combinada matematicamente para montar os 5 trechos finais que a IA usa para responder.",
    "Na prática, isso significa: se a pergunta usa um termo técnico exato que aparece literalmente na documentação, a busca lexical ajuda a garantir que esse trecho apareça; se a pergunta é feita com outras palavras, a busca vetorial ainda encontra o trecho certo pelo significado. A decisão de abstenção, aliás, continua baseada só na melhor similaridade vetorial pura. Ela não muda por causa da fusão híbrida, para não invalidar a calibração que testei."])));
parts.push(step("7.3", "Segunda Production: PublicHealth (opcional)",
  "<p>Existe uma segunda Production, <code>PublicHealthProduction</code>, que consome uma API pública real (<code>disease.sh</code>) e trata indisponibilidade sem inventar dados. Só uma Production roda por vez, então mostrar ao vivo exige parar a atual. Decida se vale o tempo do vídeo ou se só cita.</p>",
  where("T", "Para trocar para a PublicHealth (cole as 4 linhas de uma vez):"),
  cmd(`docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
do ##class(Ens.Director).StopProduction()
set sc=##class(Ens.Director).StartProduction("Guardian.Production.PublicHealthProduction")
write "Start PublicHealth sc: ",sc,!
halt
EOF`, "Bloco colado de uma vez (várias linhas de propósito)"),
  where("T", "Para <b>voltar</b> à Production principal (obrigatório se for gravar mais alguma coisa depois):"),
  cmd(`docker exec -i iris-guardian iris session IRIS -U GUARDIAN <<'EOF'
do ##class(Ens.Director).StopProduction()
set sc=##class(Ens.Director).RecoverProduction()
set sc=##class(Ens.Director).StartProduction("Guardian.Production.GuardianProduction")
write "Start Guardian sc: ",sc,!
halt
EOF`, "Bloco colado de uma vez (várias linhas de propósito)")));

// ------------------------------------------------------------------ SECAO 8
parts.push(section("8. Metodologia com IA (1 minuto)"));
parts.push(step("8.1", "Mostrar a pasta de prompts",
  where("T", "No Finder (ou no editor de código), abra a pasta <code>entregaveis/Prompts/</code> do projeto. São 10 arquivos com a sequência real de prompts por fase, com os erros reais encontrados e corrigidos. Você <b>não</b> precisa ler nada; só aponte que existe e abra um arquivo rapidamente como exemplo."),
  shot("P25", "Pasta entregaveis/Prompts com os 10 arquivos",
    "Finder do Mac", "(1) pasta Prompts, (2) um arquivo aberto como exemplo")));

// ------------------------------------------------------------------ SECAO 9
parts.push(section("9. Encerramento (30 a 45 segundos)"));
parts.push(step("9.1", "Falar o fechamento",
  where("G", "Deixe o Guardian aberto no <b>Monitor</b>."),
  say(["Esse foi o IRIS Production Guardian: um Production Monitor em tempo real, um AI Incident Investigator que fundamenta hipóteses em evidência sem executar nada sozinho, e um RAG Assistant que cita a fonte e sabe dizer que não sabe. Além do escopo obrigatório, entreguei quatro bônus: roteamento por Business Rules, busca híbrida vetorial e lexical, um segundo provedor de IA para geração de resposta, e uma segunda produção que integra uma API pública de saúde. Todo o código está aberto no repositório GitHub, o link está na descrição deste vídeo. Obrigado por assistir."]),
  '<p><b>Link para mostrar na tela:</b> <code>https://github.com/sergiofsq/iris-production-guardian</code></p>' +
  '<p>O link do vídeo publicado e o link do Open Exchange <b>ainda não existem</b> na hora da gravação, então não dá para citá-los. Preencha depois em <code>entregaveis/Artigo_Comunidade_PT.md</code>.</p>'));

// ------------------------------------------------------------------ LIMPEZA + CHECKLIST
parts.push(section("Limpeza depois de gravar"));
parts.push(step("L.1", "Parar o loop", where("T", 'No Terminal 2, pressione <b>Ctrl+C</b>. Se ele estiver em segundo plano, no Terminal 1: <code>pkill -f loop_trafego_saudavel</code> (ou <code>pkill -f "durable/guardian/in"</code> se você colou o bloco em vez de rodar o script).')));
parts.push(step("L.2", "Limpar as pastas",
  where("T", "No Terminal 1:"),
  cmd("docker exec -i iris-guardian sh -c 'D=/durable/guardian; rm -f $D/in/* $D/archive/* $D/out/* $D/out_priority/*'")));
parts.push(step("L.3", "Deixar a Production certa rodando",
  "<p>Confirme que a Production ativa é <code>Guardian.Production.GuardianProduction</code> e não a <code>PublicHealthProduction</code> (se você testou o item 7.3).</p>"));
parts.push(section("Checklist final antes de publicar"));
parts.push(`
<ul class="check">
<li>Nenhuma chave de API, senha ou dado pessoal visível em nenhum frame (revise aberturas de terminal e a barra de favoritos).</li>
<li>Interface e texto em inglês na tela, nas quatro páginas do Guardian (botão EN).</li>
<li>Nenhum corte esconde uma espera real nem sugere um tempo falso de recuperação.</li>
<li>Capturar manualmente P01 (mesa de gravação) e P25 (Finder) — os dois únicos prints que dependem da tela física do seu Mac.</li>
<li>Depois de publicado, preencher o link do vídeo em <code>entregaveis/Artigo_Comunidade_PT.md</code>.</li>
</ul>
`);

// ------------------------------------------------------------------ ANEXO A (só se sobrar pendência)
if (PENDING.length) {
  parts.push('<div class="pagebreak"></div>');
  parts.push(section("Anexo A. Prints que ainda precisam ser capturados",
    "Só restam os dois que exigem a tela física do seu Mac."));
  const rows = PENDING.map(([p, t, w, m]) => `<tr><td><b>${e(p)}</b></td><td>${e(t)}</td><td>${e(w)}</td><td>${e(m)}</td></tr>`).join("");
  parts.push(`<table class="t3 anexo"><tr><th>ID</th><th>O que capturar</th><th>Tela</th><th>Bolinha vermelha em</th></tr>${rows}</table>`);
}

const CSS = `
@page { size: A4; margin: 14mm 13mm 16mm 13mm; }
* { box-sizing: border-box; }
body { font-family: "Liberation Sans", "DejaVu Sans", Arial, sans-serif; color:#1b2340; font-size:10.4pt; line-height:1.45; }
.cover { background: linear-gradient(135deg,#0A1965,#102F8B); color:#fff; padding:34px 30px; border-radius:10px; margin-bottom:16px; }
.brand { color:#0FD1C4; font-weight:700; letter-spacing:2px; font-size:10pt; }
.cover h1 { margin:6px 0 4px; font-size:28pt; border:none; padding:0; color:#fff; }
.tagline { font-size:12pt; color:#dbe4ff; }
.meta { margin-top:14px; font-size:9pt; color:#b9c8f5; }
h2 { color:#0A1965; font-size:15pt; margin:22px 0 4px; border-bottom:3px solid #0FD1C4; padding-bottom:4px; page-break-after:avoid; }
.sub { color:#5a6486; font-size:9.6pt; margin-bottom:8px; font-style:italic; }
.step { border:1px solid #d6ddf0; border-radius:8px; padding:10px 12px; margin:10px 0; background:#fff; }
.stephead { font-weight:700; font-size:11.6pt; color:#0A1965; margin-bottom:6px; page-break-after:avoid; }
.num { display:inline-block; background:#01989C; color:#fff; border-radius:4px; padding:1px 7px; margin-right:8px; font-size:9.6pt; }
.where { margin:6px 0; }
.tag { display:inline-block; font-size:7.6pt; font-weight:700; letter-spacing:.6px; padding:2px 6px; border-radius:3px; color:#fff; margin-right:4px; vertical-align:1px; }
.tag.t { background:#333b5c; } .tag.g { background:#01989C; } .tag.p { background:#7a3fb3; }
pre { background:#0B1440; color:#F2F6FF; padding:9px 11px; border-radius:6px; font-family:"DejaVu Sans Mono",monospace; font-size:7.6pt; line-height:1.4; white-space:pre-wrap; word-break:break-all; margin:3px 0 8px; page-break-inside:avoid; border:1pt solid #1E3A8A; }
pre.prompt { font-size:7.2pt; }
.cmdlabel { font-size:7.8pt; font-weight:700; color:#5a6486; margin-top:6px; text-transform:uppercase; letter-spacing:.5px; }
code { font-family:"DejaVu Sans Mono",monospace; background:#eef1fb; border-radius:3px; padding:0 3px; font-size:8.8pt; color:#0A1965; }
.simple { background:#effaf9; border-left:4px solid #0FD1C4; padding:7px 10px; margin:6px 0; border-radius:0 6px 6px 0; }
.say { background:#eef1fb; border-left:4px solid #0A1965; padding:7px 10px; margin:8px 0; border-radius:0 6px 6px 0; }
.say p { margin:4px 0; font-style:italic; }
.saylabel { font-size:7.6pt; font-weight:700; color:#0A1965; letter-spacing:.6px; }
.warn { background:#fff6e0; border-left:4px solid #e2a100; padding:7px 10px; margin:8px 0; border-radius:0 6px 6px 0; }
blockquote { margin:6px 0; padding:6px 12px; background:#f4f6fc; border-left:4px solid #01989C; font-weight:700; }
.shot { margin:8px 0; page-break-inside:avoid; }
.shot img { width:100%; border:1px solid #c9d1e8; border-radius:5px; }
.cap { font-size:8.4pt; color:#4a5478; margin-top:3px; }
.cap.real { color:#1a7a3c; }
.shot.pend .ph { border:2px dashed #d0392f; border-radius:8px; background:#fff5f4; padding:14px 16px; min-height:120px; }
.phid { color:#d0392f; font-weight:700; font-size:9pt; letter-spacing:.8px; }
.phtitle { font-weight:700; margin:3px 0 6px; color:#1b2340; }
.phrow { font-size:9pt; margin:2px 0; }
table { border-collapse:collapse; width:100%; margin:8px 0; }
th, td { border:1px solid #d6ddf0; padding:5px 8px; vertical-align:top; font-size:9.4pt; }
th { background:#eef1fb; color:#0A1965; text-align:left; }
.gloss td:first-child { width:26%; }
.t2 td:first-child { width:18%; white-space:nowrap; }
.simpleicon,.sayicon,.shoticon { font-weight:700; font-size:8.6pt; }
.simpleicon { color:#01989C; } .sayicon { color:#0A1965; } .shoticon { color:#d0392f; }
.pagebreak { page-break-after:always; }
.diagram { border:1px solid #d6ddf0; border-radius:8px; padding:10px 12px; margin:12px 0; background:#f8f9fe; page-break-inside:avoid; }
.dtitle { font-weight:700; color:#0A1965; margin-bottom:8px; }
.flow { display:flex; align-items:center; gap:6px; }
.box { border-radius:7px; padding:7px 8px; font-size:8.4pt; text-align:center; flex:1; border:2px solid; }
.box span { color:#4a5478; font-size:7.8pt; }
.box.in { border-color:#01989C; background:#e6f7f6; } .box.pr { border-color:#0A1965; background:#e8ecfb; }
.box.ok { border-color:#2e9e4f; background:#e8f6ec; } .box.pri { border-color:#d0392f; background:#fdeceb; }
.arrow { font-size:16pt; color:#01989C; font-weight:700; }
.fork { display:flex; flex-direction:column; gap:6px; flex:1.3; }
.dnote { font-size:8.8pt; margin-top:8px; color:#3c4670; }
ul.check li { margin:4px 0; }
.anexo td { font-size:8.6pt; }
h3 { color:#0A1965; font-size:11.5pt; margin:14px 0 4px; }
`;

const doc = `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Roteiro de Gravação V4</title><style>${CSS}</style></head><body>${parts.join("")}</body></html>`;
fs.writeFileSync(OUT_HTML, doc, "utf-8");
console.log("Wrote HTML:", OUT_HTML);

(async () => {
  const browser = await chromium.launch();
  const pg = await browser.newPage();
  await pg.goto("file://" + path.resolve(OUT_HTML));
  await pg.pdf({
    path: OUT_PDF, format: "A4", printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: "<div></div>",
    footerTemplate: '<div style="font-size:8px;color:#777;width:100%;text-align:center;">IRIS Production Guardian · Roteiro de Gravação V4 · <span class="pageNumber"></span>/<span class="totalPages"></span></div>',
    margin: { top: "14mm", bottom: "16mm", left: "13mm", right: "13mm" },
  });
  await browser.close();
  console.log("Wrote PDF:", OUT_PDF);
  console.log("pendentes:", PENDING.length);
  for (const x of PENDING) console.log(x[0], "-", x[1]);
})();

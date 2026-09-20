#!/bin/bash
# Assistente de captura de prints para o Roteiro V3 (IRIS Production Guardian).
# Roda no Terminal do Mac. Faz os comandos de docker do roteiro e, a cada print,
# chama o screencapture com o nome de arquivo certo (P01.png, P02.png...).
#
# Como usar:   cd "$HOME/Projetos/IRIS Production Guardian" && bash docs/planejamento/_v3_build/capturar_prints.sh
#
# Em cada print o script diz o que deixar na tela. Aperte Enter e ARRASTE o mouse
# para selecionar a area (como Cmd+Shift+4). Para cancelar um print, aperte Esc.
# Se um print sair ruim, rode o script de novo e responda "p" (pular) nos outros,
# ou capture so aquele com:  bash capturar_prints.sh so P12

set -u
BASE="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT="$BASE/docs/planejamento/screenshots"
mkdir -p "$OUT"
ONLY="${2:-}"          # uso: capturar_prints.sh so P12
C="iris-guardian"
LOG="/tmp/loop_guardian.log"
LOOPPID=""

say()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m%s\033[0m\n' "$*"; }
pause(){ read -r -p "  Enter para continuar... " _; }

# shot ID "o que deixar na tela"
shot() {
  local id="$1" msg="$2"
  if [ -n "$ONLY" ] && [ "$ONLY" != "$id" ]; then return; fi
  say "[$id] $msg"
  read -r -p "  Enter = capturar (arraste a area) | p = pular: " a
  if [ "$a" = "p" ]; then warn "  pulado"; return; fi
  screencapture -i "$OUT/$id.png"
  if [ -f "$OUT/$id.png" ]; then echo "  salvo: $OUT/$id.png"; else warn "  nada salvo (Esc?)"; fi
}

# shotdelay ID segundos "mensagem": captura a tela toda depois de N segundos (para o overlay de carregamento)
shotdelay() {
  local id="$1" t="$2" msg="$3"
  if [ -n "$ONLY" ] && [ "$ONLY" != "$id" ]; then return; fi
  say "[$id] $msg"
  read -r -p "  Enter = iniciar contagem de ${t}s (clique no botao dentro desse tempo) | p = pular: " a
  if [ "$a" = "p" ]; then warn "  pulado"; return; fi
  screencapture -x -T "$t" "$OUT/$id.png" && echo "  salvo: $OUT/$id.png (tela inteira; eu recorto depois)"
}

d() { docker exec -i "$C" "$@"; }

cleanup() { [ -n "$LOOPPID" ] && kill "$LOOPPID" 2>/dev/null; }
trap cleanup EXIT

if [ -n "$ONLY" ]; then
  echo "Modo unico: so o print $ONLY"
fi

say "PREPARO: navegador com Guardian (idioma EN, barra de favoritos oculta) e aba do Management Portal logadas."
say "Os prints de navegador devem ser feitos no navegador da gravacao (Chrome ou o do app Claude)."
pause

# ---------------- 0. Antes de gravar
d true 2>/dev/null || { docker start "$C" >/dev/null; sleep 5; }
d sh -c 'D=/durable/guardian; rm -f $D/in/* $D/archive/* $D/out/* $D/out_priority/* && chmod 755 $D/out $D/out_priority'

shot P01 "Mesa de gravacao: Terminal 1, Terminal 2 e navegador lado a lado. Arrume as janelas e selecione a tela toda."

echo "--- estado da Production ---"
d iris session IRIS -U GUARDIAN <<'EOF'
write ##class(Ens.Director).GetProductionStatus(.tName,.tState),!
write "Nome: ",tName," Estado: ",tState,!
halt
EOF
shot P02 "Deixe este Terminal visivel mostrando 'Estado: 1' (role a tela se preciso) e selecione so o terminal."

shot P03 "Guardian: botao de idioma no canto superior da barra lateral mostrando EN."
shot P04 "Guardian: tela inicial (Production Monitor), idioma EN, todos healthy."

# ---------------- 2. Saudavel
shot P05 "Guardian > Monitor (menu lateral): State Running e os quatro hosts healthy."

say "Iniciando o loop de trafego (mensagem LOW a cada 6s) em segundo plano..."
(
  I=0
  while true; do
    I=$((I + 1))
    ID="LOOP-$(date +%H%M%S)-${I}"
    FILE="/durable/guardian/in/loop_${I}.txt"
    MSG="${ID}|IRIS.Service.OrderIngest|LOW|Trafego continuo de demonstracao #${I}"
    docker exec -i "$C" sh -c "echo '$MSG' > $FILE && chown irisowner:irisowner $FILE"
    echo "[$(date +%T)] enviado ${ID}"
    sleep 6
  done
) > "$LOG" 2>&1 &
LOOPPID=$!
sleep 14
echo "--- ultimas linhas do loop ---"; tail -4 "$LOG"
shot P06 "Terminal mostrando as linhas '[hh:mm:ss] enviado LOOP-...' (este e o equivalente ao Terminal 2). Selecione so as linhas acima."

shot P07 "Guardian > Monitor: contadores de Mensagens subindo (aperte Enter duas vezes, com ~15s de diferenca, se quiser comparar; aqui vale um so)."
echo "--- pasta out ---"; d ls -la /durable/guardian/out
shot P08 "Terminal com a lista da pasta out (arquivos loop_*.txt)."

shot P09 "Management Portal (home): menu esquerdo Interoperability > View > Messages, com o submenu aberto."
shot P10 "Management Portal > Interoperability > View > Messages: lista com mensagens LOOP-... Status Completed."

# ---------------- 3. Falha
say "FALHA CONTROLADA: bloqueando out_priority e disparando INC-003"
d chmod 555 /durable/guardian/out_priority
shot P11 "Terminal com o comando chmod 555 acima (role para mostrar o comando, se preciso)."
d sh -c 'F=/durable/guardian/in/demo3.txt; echo "INC-003|IRIS.Service.PaymentGateway|CRITICAL|Falha de escrita simulada no destino" > $F && chown irisowner:irisowner $F'
warn "Aguarde ~25 segundos (FailureTimeout real) com o Guardian > Monitor na tela..."
sleep 25
shot P12 "Guardian > Monitor: IncidentRouterProcess e PriorityOutputOperation amarelos (degraded); FileIncidentService e FileOutputOperation verdes."
shot P13 "Management Portal > Interoperability > View > Messages: mensagem INC-003 com Status Error (clique em atualizar antes)."
shot P14 "Detalhe da mensagem INC-003 com o texto ERROR #5005 (clique na mensagem para abrir)."

# ---------------- 4. Investigator
shot P15 "Guardian > Investigator: Component = Guardian.Operation.PriorityOutputOperation, Window = 60 (antes de clicar em Investigate)."
shotdelay P16 3 "Overlay de carregamento: nos proximos 3s clique em Investigate; a tela inteira sera capturada."
shot P17 "Resultado da investigacao: Observacao, Hipotese e Lacunas (role a pagina para mostrar as tres partes)."

# ---------------- 5. RAG
shot P18 "Guardian > RAG Assistant (Gemini): pergunta 'Qual a causa do erro #5005?' respondida, com a fonte citada."
shot P19 "RAG Assistant (Gemini): pergunta 'Qual a receita de bolo de chocolate?' com a resposta de abstencao."
shot P20 "Guardian > RAG Assistant (Groq): mesma pergunta 1, resposta com fonte citada."

# ---------------- 6. Recuperacao
say "RECUPERACAO: destrancando out_priority e disparando INC-004"
d chmod 755 /durable/guardian/out_priority
d sh -c 'F=/durable/guardian/in/demo4.txt; echo "INC-004|IRIS.Service.PaymentGateway|LOW|Fluxo normal apos recuperacao do destino" > $F && chown irisowner:irisowner $F'
warn "Aguarde ~15 segundos com o Guardian > Monitor na tela..."
sleep 15
shot P21 "Guardian > Monitor: os quatro hosts de volta em healthy."
shot P22 "Management Portal > Message Viewer: INC-003 selecionado e o botao Resend visivel."

# ---------------- 7. Bonus / 8. Metodologia
shot P23 "Management Portal > Interoperability > Build > Business Rules: Rule Editor vazio com o botao Open."
shot P24 "Rule Editor: dialogo Open com Business Rules > Rule > IncidentRoutingRule."
shot R1  "Management Portal: menu Interoperability aberto em Build > Business Rules, com a Production RUNNING no painel da direita."
shot P25 "Finder: pasta entregaveis/Prompts com os 10 arquivos."

# ---------------- Limpeza
say "Limpeza: parando o loop e limpando as pastas"
cleanup; LOOPPID=""
d sh -c 'D=/durable/guardian; rm -f $D/in/* $D/archive/* $D/out/* $D/out_priority/*'
say "Pronto. Prints salvos em: $OUT"
ls -1 "$OUT" | sed 's/^/  /'
say "Volte ao Claude e diga: capturei os prints"

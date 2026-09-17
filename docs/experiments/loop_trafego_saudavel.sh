#!/bin/sh
# Loop de trafego saudavel para a gravacao do video de apresentacao
# (ver docs/planejamento/08_ROTEIRO_GRAVACAO_VIDEO.md, secao 2).
#
# Manda uma mensagem LOW para /durable/guardian/in a cada N segundos, para
# o Monitor mostrar contadores de fila/mensagens se movendo durante toda a
# gravacao, em vez de um unico disparo estatico. Roda no HOST (Mac), nao
# dentro do container - so chama "docker exec" repetidamente.
#
# Nao interfere na falha controlada da secao 3 do roteiro: severidade LOW e'
# roteada para /durable/guardian/out (Guardian.Rule.IncidentRoutingRule),
# nunca para /durable/guardian/out_priority (destino que a secao 3 quebra
# de proposito com "chmod 555", usado so por CRITICAL/HIGH/MEDIUM) - pode
# deixar este loop rodando o tempo todo, inclusive durante a falha, para
# provar ao vivo que so o caminho prioritario quebrou, nao a Production
# inteira.
#
# Uso:
#   sh docs/experiments/loop_trafego_saudavel.sh          # primeiro plano, Ctrl+C para parar
#   sh docs/experiments/loop_trafego_saudavel.sh &        # segundo plano
#   sh docs/experiments/loop_trafego_saudavel.sh 10       # intervalo customizado (10s em vez do padrao 6s)
#   pkill -f loop_trafego_saudavel                        # para uma instancia rodando em segundo plano

INTERVAL="${1:-6}"
I=0

echo "Enviando uma mensagem LOW a cada ${INTERVAL}s para /durable/guardian/in (Ctrl+C para parar)..."

while true; do
	I=$((I + 1))
	ID="LOOP-$(date +%H%M%S)-${I}"
	FILE="loop_${I}.txt"
	docker exec -i iris-guardian sh -c \
		"echo '${ID}|IRIS.Service.OrderIngest|LOW|Trafego continuo de demonstracao #${I}' > /durable/guardian/in/${FILE} && chown irisowner:irisowner /durable/guardian/in/${FILE}"
	echo "[$(date +%T)] enviado ${ID}"
	sleep "$INTERVAL"
done

#!/bin/sh
# Healthy traffic loop for the presentation video recording
# (see docs/planejamento/08_ROTEIRO_GRAVACAO_VIDEO_V8.pdf, section 2).
#
# Sends one LOW message to /durable/guardian/in every N seconds, so the
# Monitor shows queue/message counters moving during the whole recording
# instead of a single static burst. Runs on the HOST (Mac), not inside the
# container - it only calls "docker exec" repeatedly.
#
# It does not interfere with the controlled failure of section 3: LOW
# severity is routed to /durable/guardian/out (Guardian.Rule.IncidentRoutingRule),
# never to /durable/guardian/out_priority (the destination that section 3
# breaks on purpose with "chmod 555", used only by CRITICAL/HIGH/MEDIUM) -
# you can leave this loop running the whole time, including during the
# failure, to prove live that only the priority path broke, not the whole
# Production.
#
# Usage:
#   sh docs/experiments/healthy_traffic_loop.sh          # foreground, Ctrl+C to stop
#   sh docs/experiments/healthy_traffic_loop.sh &        # background
#   sh docs/experiments/healthy_traffic_loop.sh 10       # custom interval (10s instead of the default 6s)
#   pkill -f healthy_traffic_loop                        # stops a background instance

INTERVAL="${1:-6}"
I=0

echo "Sending one LOW message every ${INTERVAL}s to /durable/guardian/in (Ctrl+C to stop)..."

while true; do
	I=$((I + 1))
	ID="LOOP-$(date +%H%M%S)-${I}"
	FILE="/durable/guardian/in/loop_${I}.txt"
	MSG="${ID}|IRIS.Service.OrderIngest|LOW|Continuous demo traffic #${I}"
	docker exec -i iris-guardian sh -c "echo '$MSG' > $FILE && chown irisowner:irisowner $FILE"
	echo "[$(date +%T)] sent ${ID}"
	sleep "$INTERVAL"
done

/// Pagina HTML/CSS do Production Monitor (Fase 2). So apresentacao aqui -
/// os dados e as regras de saude vem de Guardian.Monitor.StatusCollector
/// (chamada diretamente em COS, sem round-trip HTTP/JS). Atualiza via
/// meta refresh (sem JS necessario para a funcionalidade principal).
Class Guardian.UI.MonitorPage Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	Set tData = ##class(Guardian.Monitor.StatusCollector).Collect()

	&html<<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="10">
<title>IRIS Production Guardian - Monitor</title>
<style>
	body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; background: #0a1965; color: #eef1ff; margin: 0; padding: 2rem; }
	h1 { color: #0fd1c4; font-size: 1.5rem; margin-bottom: 0.25rem; }
	.meta { color: #9aa4d6; font-size: 0.85rem; margin-bottom: 1.5rem; }
	.meta strong { color: #eef1ff; }
	.columns { display: flex; gap: 1.5rem; flex-wrap: wrap; }
	.column { flex: 1; min-width: 260px; }
	.column h2 { font-size: 1rem; text-transform: uppercase; letter-spacing: 0.05em; color: #9aa4d6; border-bottom: 1px solid #23306b; padding-bottom: 0.5rem; }
	.card { background: #102f8b; border-radius: 8px; padding: 1rem; margin-bottom: 0.75rem; border-left: 4px solid #555; }
	.card.healthy { border-left-color: #2ecc71; }
	.card.degraded { border-left-color: #f1c40f; }
	.card.unavailable { border-left-color: #e74c3c; }
	.card.unknown { border-left-color: #7f8c8d; }
	.card .name { font-weight: 600; font-size: 0.95rem; word-break: break-all; }
	.badge { display: inline-block; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.15rem 0.5rem; border-radius: 999px; margin-top: 0.4rem; }
	.badge.healthy { background: #1e5c3a; color: #6ee7a0; }
	.badge.degraded { background: #6b5a12; color: #ffe27a; }
	.badge.unavailable { background: #6b2020; color: #ff9a9a; }
	.badge.unknown { background: #3a3a3a; color: #c9c9c9; }
	.stats { font-size: 0.8rem; color: #b7bde8; margin-top: 0.5rem; }
	.empty { color: #6f7ac0; font-size: 0.85rem; font-style: italic; }
	.demo-note { margin-top: 2rem; font-size: 0.75rem; color: #6f7ac0; border-top: 1px solid #23306b; padding-top: 1rem; }
</style>
</head>
<body>
<h1>IRIS Production Guardian &mdash; Production Monitor</h1>
<div class="meta">
	Production: <strong>#(tData.production)#</strong> &middot;
	Estado: <strong>#(tData.productionState)#</strong> &middot;
	Coletado em: <strong>#(tData.collectedAt)#</strong> (atualiza a cada 10s)
</div>
<div class="columns">>

	Set tTypes = $ListBuild("Service", "Process", "Operation")
	Set tLabels("Service") = "Hosts de entrada (Service)"
	Set tLabels("Process") = "Hosts de processamento (Process)"
	Set tLabels("Operation") = "Hosts de saida (Operation)"

	For tI = 1:1:$ListLength(tTypes) {
		Set tType = $List(tTypes, tI)
		&html<<div class="column"><h2>#(tLabels(tType))#</h2>>

		Set tCount = 0
		Set tIter = tData.hosts.%GetIterator()
		While tIter.%GetNext(.tKey, .tHost) {
			If tHost.type = tType {
				Set tCount = tCount + 1
				Set tHealth = tHost.health
				&html<<div class="card #(tHealth)#">
	<div class="name">#(tHost.name)#</div>
	<span class="badge #(tHealth)#">#(tHealth)#</span>
	<div class="stats">
		Fila: #(tHost.queueCount)# &middot;
		Mensagens: #(tHost.messageCount)# &middot;
		Erros recentes: #(tHost.recentErrorCount)#
	</div>
</div>>
			}
		}
		If tCount = 0 {
			&html<<div class="empty">Nenhum host deste tipo.</div>>
		}
		&html<</div>>
	}

	&html<</div>
<div class="demo-note">
	Estados: <strong>healthy</strong> = sem fila pendente e sem erro recente &middot;
	<strong>degraded</strong> = fila pendente ou erro nos ultimos #(tData.errorWindowSeconds)# segundos &middot;
	<strong>unavailable</strong> = host desabilitado ou Production parada &middot;
	<strong>unknown</strong> = nenhuma mensagem registrada ainda para este host (ausencia de dado nao e saude).
	Sem serie temporal persistida nesta v1 - calculo sob demanda a cada carregamento.
</div>
</body>
</html>>

	Quit $$$OK
}

}

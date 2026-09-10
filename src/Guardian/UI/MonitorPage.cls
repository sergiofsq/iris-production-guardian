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
<link rel="stylesheet" href="/csp/guardian/assets/css/iris-guardian-theme.css">
<style>
	.ig-page-header { display: flex; align-items: center; gap: 1.5rem; padding: 0.75rem 1.5rem; background: var(--ig-bg-strong); }
	.ig-logo-badge { background: var(--ig-white); border-radius: var(--ig-radius-sm); padding: 0.35rem 0.75rem; box-shadow: var(--ig-shadow); display: flex; }
	.ig-logo-badge img { height: 60px; width: auto; display: block; }
	.ig-page-header nav { display: flex; gap: 1.25rem; margin-left: auto; }
	.ig-page-header nav a { color: var(--ig-on-bg-muted); text-decoration: none; font-size: 0.85rem; font-weight: 600; letter-spacing: 0.03em; text-transform: uppercase; padding-bottom: 2px; }
	.ig-page-header nav a:hover, .ig-page-header nav a[aria-current="page"] { color: var(--ig-on-bg-text); border-bottom: 2px solid var(--ig-teal-500); }
	main { max-width: 1100px; margin: 0 auto; padding: 2rem 1.5rem; }
	h1 { color: var(--ig-on-bg-text); font-size: 1.4rem; margin-bottom: 0.25rem; }
	.meta { color: var(--ig-on-bg-muted); font-size: 0.85rem; margin-bottom: 1.5rem; }
	.meta strong { color: var(--ig-on-bg-text); }
	.columns { display: flex; gap: 1.5rem; flex-wrap: wrap; }
	.column { flex: 1; min-width: 260px; }
	.column h2 { font-size: 1rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--ig-on-bg-muted); border-bottom: 1px solid rgba(255,255,255,0.25); padding-bottom: 0.5rem; }
	.card { background: var(--ig-surface); border: 1px solid var(--ig-border); box-shadow: var(--ig-shadow); border-radius: var(--ig-radius-sm); padding: 1rem; margin-bottom: 0.75rem; border-left: 4px solid var(--ig-status-unknown); }
	.card.healthy { border-left-color: var(--ig-status-healthy); }
	.card.degraded { border-left-color: var(--ig-status-degraded); }
	.card.unavailable { border-left-color: var(--ig-status-down); }
	.card.unknown { border-left-color: var(--ig-status-unknown); }
	.card .name { font-weight: 600; font-size: 0.95rem; word-break: break-all; color: var(--ig-text); }
	.badge { display: inline-block; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.15rem 0.5rem; border-radius: 999px; margin-top: 0.4rem; font-weight: 600; }
	.badge.healthy { background: color-mix(in srgb, var(--ig-status-healthy) 15%, white); color: var(--ig-status-healthy); }
	.badge.degraded { background: color-mix(in srgb, var(--ig-status-degraded) 18%, white); color: var(--ig-status-degraded); }
	.badge.unavailable { background: color-mix(in srgb, var(--ig-status-down) 15%, white); color: var(--ig-status-down); }
	.badge.unknown { background: color-mix(in srgb, var(--ig-status-unknown) 18%, white); color: var(--ig-status-unknown); }
	.stats { font-size: 0.8rem; color: var(--ig-text-muted); margin-top: 0.5rem; }
	.trend { font-size: 0.75rem; color: var(--ig-text-muted); margin-top: 0.35rem; font-family: var(--ig-font-mono); }
	.badge.stuck { background: color-mix(in srgb, var(--ig-status-down) 15%, white); color: var(--ig-status-down); margin-left: 0.35rem; }
	.empty { color: var(--ig-text-muted); font-size: 0.85rem; font-style: italic; }
	.demo-note { margin-top: 2rem; font-size: 0.75rem; color: var(--ig-on-bg-muted); border-top: 1px solid rgba(255,255,255,0.2); padding-top: 1rem; }
</style>
</head>
<body>
<header class="ig-page-header">
	<div class="ig-logo-badge"><img src="/csp/guardian/iris-guardian-logo-header.png" alt="IRIS Guardian"></div>
	<nav>
		<a href="Guardian.UI.MonitorPage.cls" aria-current="page">Monitor</a>
		<a href="Guardian.UI.InvestigatorPage.cls">Investigator</a>
		<a href="Guardian.UI.RAGPage.cls">RAG Assistant</a>
	</nav>
</header>
<main>
<h1>Production Monitor</h1>
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
	<span class="badge #(tHealth)#">#(tHealth)#</span>>
				If tHost.stuck {
					&html<<span class="badge stuck">travado</span>>
				}
				&html<<div class="stats">
		Fila: #(tHost.queueCount)# &middot;
		Mensagens: #(tHost.messageCount)# &middot;
		Erros recentes: #(tHost.recentErrorCount)#
	</div>>
				Set tTrend = ##class(Guardian.Monitor.StatusCollector).RecentSamples(tHost.name, 10)
				If tTrend.%Size() > 1 {
					Set tTrendStr = ""
					Set tTrendIter = tTrend.%GetIterator()
					While tTrendIter.%GetNext(.tTrendKey, .tSample) {
						Set tTrendStr = tTrendStr _ $Select(tTrendStr'="":", ", 1:"") _ tSample.queueCount
					}
					&html<<div class="trend">tendência de fila (#(tTrend.%Size())# amostras): #(tTrendStr)#</div>>
				}
				&html<</div>>
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
	<strong>unknown</strong> = nenhuma mensagem registrada ainda para este host (ausencia de dado nao e saude) &middot;
	<strong>travado</strong> = fila positiva e sem esvaziar nas ultimas 3 amostras persistidas.
	Serie temporal persistida a cada carregamento desta pagina ou chamada da API (/api/guardian/status) -
	sem coletor agendado independente nesta v1.
</div>
</main>
</body>
</html>>

	Quit $$$OK
}

}

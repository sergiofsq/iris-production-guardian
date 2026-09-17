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
	Set tHtmlLang = ##class(Guardian.UI.I18n).HtmlLang()
	Set tThemeAttr = ##class(Guardian.UI.I18n).ThemeAttr()

	&html<<!DOCTYPE html>
<html lang="#(tHtmlLang)#"#(tThemeAttr)#>
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="10">
<title>IRIS Production Guardian - #(##class(Guardian.UI.I18n).T("monitor.h1"))#</title>
<link rel="stylesheet" href="/csp/guardian/assets/css/iris-guardian-theme.css?v=3">
<style>
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
<div class="ig-shell">>

	Do ##class(Guardian.UI.Shared).RenderSidebar("monitor")

	&html<<main class="ig-main">
<h1>#(##class(Guardian.UI.I18n).T("monitor.h1"))#</h1>
<div class="meta">
	#(##class(Guardian.UI.I18n).T("monitor.meta_production"))# <strong>#(tData.production)#</strong> &middot;
	#(##class(Guardian.UI.I18n).T("monitor.meta_state"))# <strong>#(tData.productionState)#</strong> &middot;
	#(##class(Guardian.UI.I18n).T("monitor.meta_collected"))# <strong>#(tData.collectedAt)#</strong> #(##class(Guardian.UI.I18n).T("monitor.meta_refresh"))#
</div>
<div class="columns">>

	Set tTypes = $ListBuild("Service", "Process", "Operation")
	Set tLabels("Service") = ##class(Guardian.UI.I18n).T("monitor.col_service")
	Set tLabels("Process") = ##class(Guardian.UI.I18n).T("monitor.col_process")
	Set tLabels("Operation") = ##class(Guardian.UI.I18n).T("monitor.col_operation")

	For tI = 1:1:$ListLength(tTypes) {
		Set tType = $List(tTypes, tI)
		&html<<div class="column"><h2>#(tLabels(tType))#</h2>>

		Set tCount = 0
		Set tIter = tData.hosts.%GetIterator()
		While tIter.%GetNext(.tKey, .tHost) {
			If tHost.type = tType {
				Set tCount = tCount + 1
				Set tHealth = tHost.health
				Set tHealthLabel = ##class(Guardian.UI.I18n).HealthLabel(tHealth)
				&html<<div class="card #(tHealth)#">
	<div class="name">#(tHost.name)#</div>
	<span class="badge #(tHealth)#">#(tHealthLabel)#</span>>
				If tHost.stuck {
					&html<<span class="badge stuck">#(##class(Guardian.UI.I18n).HealthLabel("stuck"))#</span>>
				}
				&html<<div class="stats">
		#(##class(Guardian.UI.I18n).T("monitor.queue"))# #(tHost.queueCount)# &middot;
		#(##class(Guardian.UI.I18n).T("monitor.messages"))# #(tHost.messageCount)# &middot;
		#(##class(Guardian.UI.I18n).T("monitor.recent_errors"))# #(tHost.recentErrorCount)#
	</div>>
				Set tTrend = ##class(Guardian.Monitor.StatusCollector).RecentSamples(tHost.name, 10)
				If tTrend.%Size() > 1 {
					Set tTrendStr = ""
					Set tTrendIter = tTrend.%GetIterator()
					While tTrendIter.%GetNext(.tTrendKey, .tSample) {
						Set tTrendStr = tTrendStr _ $Select(tTrendStr'="":", ", 1:"") _ tSample.queueCount
					}
					Set tTrendLabel = $Replace(##class(Guardian.UI.I18n).T("monitor.trend"), "#N#", tTrend.%Size())
					&html<<div class="trend">#(tTrendLabel)# #(tTrendStr)#</div>>
				}
				&html<</div>>
			}
		}
		If tCount = 0 {
			&html<<div class="empty">#(##class(Guardian.UI.I18n).T("monitor.no_hosts_type"))#</div>>
		}
		&html<</div>>
	}

	Set tLegend = ##class(Guardian.UI.I18n).T("monitor.legend")
	Set tLegend = $Replace(tLegend, "#WINDOW#", tData.errorWindowSeconds)

	&html<</div>
<div class="demo-note">
	#(tLegend)#
</div>
</main>
</div>
</body>
</html>>

	Quit $$$OK
}

}

/// Marcacao compartilhada entre as paginas (Fase 2-4). Unico papel hoje: a
/// sidebar persistente (logo, navegacao, resumo compacto e ao vivo do
/// Production Monitor), para que o Monitor continue visivel quando o
/// usuario esta no Investigator ou no RAG Assistant - decisao de
/// 11/09/2026, mesma fonte de verdade que Guardian.UI.MonitorPage usa para
/// a vista detalhada (Guardian.Monitor.StatusCollector), sem JS/iframe.
Class Guardian.UI.Shared Extends %RegisteredObject
{

/// pCurrentPage: "monitor", "investigator", "rag" ou "ragalt" - controla
/// qual link da nav recebe aria-current="page".
ClassMethod RenderSidebar(pCurrentPage As %String) As %Status
{
	Set tData = ##class(Guardian.Monitor.StatusCollector).Collect()
	Set tOnMonitor = $Select(pCurrentPage="monitor":" aria-current=""page""", 1:"")
	Set tOnInvestigator = $Select(pCurrentPage="investigator":" aria-current=""page""", 1:"")
	Set tOnRAG = $Select(pCurrentPage="rag":" aria-current=""page""", 1:"")
	Set tOnRAGAlt = $Select(pCurrentPage="ragalt":" aria-current=""page""", 1:"")

	&html<<aside class="ig-sidebar">
	<div class="ig-logo-badge"><img src="/csp/guardian/iris-guardian-logo-header.png" alt="IRIS Guardian"></div>
	<nav class="ig-sidebar-nav">
		<a href="Guardian.UI.MonitorPage.cls"#(tOnMonitor)#>Monitor</a>
		<a href="Guardian.UI.InvestigatorPage.cls"#(tOnInvestigator)#>Investigator</a>
		<a href="Guardian.UI.RAGPage.cls"#(tOnRAG)#>RAG Assistant (Gemini)</a>
		<a href="Guardian.UI.RAGAltPage.cls"#(tOnRAGAlt)#>RAG Assistant (novo modelo)</a>
	</nav>
	<div class="ig-sidebar-monitor">
	<h3>Production Monitor</h3>
	<div class="ig-sidebar-meta">#(tData.production)#<br>#(tData.productionState)# &middot; #(tData.collectedAt)#</div>>

	Set tIter = tData.hosts.%GetIterator()
	While tIter.%GetNext(.tKey, .tHost) {
		&html<<div class="ig-mini-host">
	<span class="ig-mini-name" title="#(tHost.name)#">#(tHost.name)#</span>
	<span class="ig-mini-dot #(tHost.health)#" title="#(tHost.health)# - fila #(tHost.queueCount)#"></span>
</div>>
	}

	If tData.hosts.%Size() = 0 {
		&html<<div class="ig-sidebar-meta">Nenhum host ativo.</div>>
	}

	&html<<a class="ig-sidebar-link" href="Guardian.UI.MonitorPage.cls">Ver detalhes completos &rarr;</a>
	</div>
</aside>>

	Quit $$$OK
}

}

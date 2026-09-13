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

	Set tLang = ##class(Guardian.UI.I18n).Lang()
	Set tLangTarget = $Select(tLang="en":"PT", 1:"EN")
	Set tIsDark = (%request.GetCookie("ig_theme", "light") = "dark")
	Set tThemeIcon = $Select(tIsDark:"&#9788;", 1:"&#9789;")

	&html<<aside class="ig-sidebar">
	<div class="ig-toolbar">
		<button type="button" class="ig-icon-btn" id="ig-theme-toggle" title="#(##class(Guardian.UI.I18n).T("toggle.theme"))#" aria-label="#(##class(Guardian.UI.I18n).T("toggle.theme"))#">#(tThemeIcon)#</button>
		<button type="button" class="ig-icon-btn" id="ig-lang-toggle" title="#(##class(Guardian.UI.I18n).T("toggle.lang"))#" aria-label="#(##class(Guardian.UI.I18n).T("toggle.lang"))#">#(tLangTarget)#</button>
	</div>
	<div class="ig-logo-badge">
		<img src="/csp/guardian/production-guardian-logo.png" alt="Production Guardian" class="ig-logo-light">
		<img src="/csp/guardian/production-guardian-logo-dark.png" alt="Production Guardian" class="ig-logo-dark">
	</div>
	<nav class="ig-sidebar-nav">
		<a href="Guardian.UI.MonitorPage.cls"#(tOnMonitor)#>#(##class(Guardian.UI.I18n).T("nav.monitor"))#</a>
		<a href="Guardian.UI.InvestigatorPage.cls"#(tOnInvestigator)#>#(##class(Guardian.UI.I18n).T("nav.investigator"))#</a>
		<a href="Guardian.UI.RAGPage.cls"#(tOnRAG)#>#(##class(Guardian.UI.I18n).T("nav.rag"))#</a>
		<a href="Guardian.UI.RAGAltPage.cls"#(tOnRAGAlt)#>#(##class(Guardian.UI.I18n).T("nav.ragalt"))#</a>
	</nav>
	<div class="ig-sidebar-monitor">
	<h3>#(##class(Guardian.UI.I18n).T("sidebar.production_monitor"))#</h3>
	<div class="ig-sidebar-meta">#(tData.production)#<br>#(tData.productionState)# &middot; #(tData.collectedAt)#</div>>

	Set tQueueWord = ##class(Guardian.UI.I18n).T("sidebar.queue_word")
	Set tIter = tData.hosts.%GetIterator()
	While tIter.%GetNext(.tKey, .tHost) {
		Set tHealthLabel = ##class(Guardian.UI.I18n).HealthLabel(tHost.health)
		&html<<div class="ig-mini-host">
	<span class="ig-mini-name" title="#(tHost.name)#">#(tHost.name)#</span>
	<span class="ig-mini-dot #(tHost.health)#" title="#(tHealthLabel)# - #(tQueueWord)# #(tHost.queueCount)#"></span>
</div>>
	}

	If tData.hosts.%Size() = 0 {
		&html<<div class="ig-sidebar-meta">#(##class(Guardian.UI.I18n).T("sidebar.no_hosts"))#</div>>
	}

	&html<<a class="ig-sidebar-link" href="Guardian.UI.MonitorPage.cls">#(##class(Guardian.UI.I18n).T("sidebar.details_link"))# &rarr;</a>
	</div>
</aside>
<script>
(function () {
	function setCookie(name, value) {
		document.cookie = name + "=" + value + "; path=/; max-age=31536000; SameSite=Lax";
	}
	var themeBtn = document.getElementById("ig-theme-toggle");
	if (themeBtn) {
		themeBtn.addEventListener("click", function () {
			var isDark = document.documentElement.getAttribute("data-theme") === "dark";
			if (isDark) {
				document.documentElement.removeAttribute("data-theme");
				themeBtn.innerHTML = "&#9789;";
			} else {
				document.documentElement.setAttribute("data-theme", "dark");
				themeBtn.innerHTML = "&#9788;";
			}
			setCookie("ig_theme", isDark ? "light" : "dark");
		});
	}
	var langBtn = document.getElementById("ig-lang-toggle");
	if (langBtn) {
		langBtn.addEventListener("click", function () {
			var current = document.documentElement.getAttribute("lang") === "en" ? "en" : "pt";
			var next = current === "en" ? "pt" : "en";
			setCookie("ig_lang", next);
			location.reload();
		});
	}
})();
</script>>

	Quit $$$OK
}

/// Prepara texto dinamico (resposta do modelo, trechos de documentos) para
/// exibicao em HTML: escapa primeiro (nunca confia em conteudo vindo de
/// documentos ingeridos ou do modelo de IA para virar HTML puro - alem de
/// poder quebrar o layout, ex.: mensagens de erro reais do IRIS trazem
/// `<Ens>ErrFailureTimeout`, um doc ou resposta contendo isso sem escapar
/// vira uma tag HTML invalida e some da tela) e so DEPOIS aplica uma
/// formatacao leve de Markdown (os proprios documentos/respostas usam
/// **negrito**, `code` e cabecalhos "#") - sem depender de uma biblioteca
/// de markdown completa. Correcao de 12/09/2026: antes disso o texto ia
/// cru para a pagina, então tabelas/negrito/code apareciam com os
/// simbolos de marcacao literais (`**`, `` ` ``, `#`) em vez de formatados,
/// dificultando a leitura ("Fontes usadas" no RAG Assistant).
ClassMethod FormatText(pText As %String) As %String
{
	Set tHtml = $ZConvert(pText, "O", "HTML")

	// Code spans `algo` -> <code>algo</code>
	Set tHtml = ##class(%Regex.Matcher).%New("`([^`]+)`", tHtml).ReplaceAll("<code>$1</code>")

	// Negrito **algo** -> <strong>algo</strong>
	Set tHtml = ##class(%Regex.Matcher).%New("\*\*([^*]+)\*\*", tHtml).ReplaceAll("<strong>$1</strong>")

	// Cabecalhos markdown ("# Titulo", "## Titulo", ...) no inicio da linha
	// - sem os simbolos "#" literais, so em destaque.
	Set tHtml = ##class(%Regex.Matcher).%New("(?m)^#{1,6}[ \t]*(.+)$", tHtml).ReplaceAll("<strong>$1</strong>")

	Quit tHtml
}

}

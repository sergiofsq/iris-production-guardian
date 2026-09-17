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

/// Overlay de carregamento em estilo modal (17/09/2026, ver Ajustes.txt
/// itens 1 e 3) - chamado uma vez por pagina, junto com RenderLoadingScript
/// abaixo, pelas 3 paginas com formulario que dispara uma chamada de IA
/// (Guardian.UI.RAGPage, RAGAltPage, InvestigatorPage). pBannerKey e a
/// chave I18n da mensagem exibida (ex. "rag.loading_banner"). Fica oculto
/// (atributo "hidden") ate o JS de RenderLoadingScript revelar no submit.
/// A logo ao lado do spinner (Ajustes.txt item 4, 17/09/2026) reaproveita o
/// mesmo par de PNGs claro/escuro e o mesmo troca-automatico por tema que a
/// sidebar ja usa (ver .ig-logo-badge acima) - nenhum dos dois PNGs e'
/// transparente, entao precisam do proprio "badge" (fundo solido + sombra)
/// para nao aparecerem com uma borda recortada sobre o overlay escuro.
ClassMethod RenderLoadingOverlay(pBannerKey As %String) As %Status
{
	&html<<div class="ig-loading-overlay" id="ig-loading" hidden role="status" aria-live="polite">
	<div class="ig-loading-modal">
		<div class="ig-loading-brand">
			<div class="ig-loading-logo-badge">
				<img src="/csp/guardian/production-guardian-logo.png" alt="Production Guardian" class="ig-logo-light">
				<img src="/csp/guardian/production-guardian-logo-dark.png" alt="Production Guardian" class="ig-logo-dark">
			</div>
			<div class="ig-spinner" aria-hidden="true">
				<span></span><span></span><span></span><span></span>
				<span></span><span></span><span></span><span></span>
				<span></span><span></span><span></span><span></span>
			</div>
		</div>
		<p class="ig-loading-text">#(##class(Guardian.UI.I18n).T(pBannerKey))#</p>
	</div>
</div>>

	Quit $$$OK
}

/// Script de submit compartilhado pelas mesmas 3 paginas (ver
/// RenderLoadingOverlay acima) - desabilita o botao, revela o overlay e
/// busca a MESMA URL via fetch() em vez de deixar o formulario navegar de
/// verdade.
///
/// Por que fetch() e nao form.submit(): as 3 paginas sao formularios GET
/// simples (recarregam a pagina inteira, filosofia original do projeto -
/// "sem chamada assincrona", ver comentario de classe de RAGPage) - a
/// primeira versao deste script so adiava a navegacao com requestAnimationFrame
/// duplo + um atraso minimo antes de chamar form.submit(). Isso resolvia o
/// loader nao aparecer no clique (Ajustes.txt item 1), mas nao resolvia ele
/// SUMIR CEDO DEMAIS num processamento realmente lento: confirmado ao vivo
/// com Playwright segurando a resposta do servidor por 4s de proposito
/// (interceptando a requisicao) que o navegador destroi o contexto JS da
/// pagina antiga poucas centenas de ms depois de form.submit() ser chamado
/// - MUITO antes da resposta chegar, nao quando ela chega. Ou seja, durante
/// o processamento real o usuario via a tela de carregamento NATIVA do
/// navegador (em branco), nao o nosso overlay - o oposto do que Ajustes.txt
/// pediu ("o loader ficar ativo até a página acabar de processar").
/// form.submit() so foi trocado por fetch(); o restante do fluxo (overlay,
/// desabilitar botao) e o mesmo.
///
/// Com fetch(), a pagina atual nunca e descartada: a resposta (o MESMO HTML
/// completo que a pagina sempre gerou, servidor sem nenhuma mudanca) chega
/// como texto, e document.open()/write()/close() substitui a pagina inteira
/// no MESMO documento, sem navegacao - o overlay so some quando o novo
/// conteudo esta de fato pronto para substituir o antigo. Um erro de rede
/// real (servidor fora do ar) cai no catch, que faz form.submit() como
/// ultimo recurso (navegacao de verdade) para o usuario nao ficar preso
/// numa tela de carregamento eterna.
///
/// MIN_VISIBLE_MS evita que uma resposta MUITO rapida (RAG que abstem sem
/// chamar o modelo, por exemplo) faca o overlay aparecer e sumir tao rapido
/// que pareca um "flash" em vez de um sinal de carregamento perceptivel.
ClassMethod RenderLoadingScript() As %Status
{
	&html<<script>
(function () {
	var MIN_VISIBLE_MS = 500;
	var form = document.querySelector("form");
	if (!form) { return; }
	form.addEventListener("submit", function (evt) {
		var btn = form.querySelector("button[type=submit]");
		if (!btn || btn.disabled) { return; }
		evt.preventDefault();
		btn.disabled = true;
		btn.setAttribute("aria-busy", "true");
		var loadingText = btn.getAttribute("data-loading-text");
		if (loadingText) { btn.textContent = loadingText; }
		var overlay = document.getElementById("ig-loading");
		if (overlay) { overlay.hidden = false; }
		document.body.classList.add("ig-modal-open");

		var params = new URLSearchParams(new FormData(form)).toString();
		var baseUrl = form.action.split("?")[0];
		var url = baseUrl + (params ? "?" + params : "");
		var startedAt = Date.now();

		fetch(url, { credentials: "same-origin" })
			.then(function (resp) { return resp.text(); })
			.then(function (html) {
				var elapsed = Date.now() - startedAt;
				var wait = Math.max(0, MIN_VISIBLE_MS - elapsed);
				setTimeout(function () {
					try { history.pushState(null, "", url); } catch (e) { /* ignore */ }
					document.open();
					document.write(html);
					document.close();
				}, wait);
			})
			.catch(function () {
				form.submit();
			});
	});
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

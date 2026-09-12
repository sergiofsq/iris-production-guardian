/// Pagina do RAG Assistant (Fase 3). So apresentacao aqui - recuperacao,
/// geracao, citacao e abstencao vem de Guardian.RAG.Query. Formulario
/// HTML simples (POST/GET), sem JS - a geracao pode levar alguns
/// segundos (modelo com raciocinio interno), entao um recarregamento de
/// pagina e mais robusto que uma chamada assincrona.
///
/// 11/09/2026: quando ha uma investigacao recente do Investigator
/// (Guardian_Investigator.Investigation), mostra o resultado dela acima do
/// formulario e sugere uma pergunta pronta - faz sentido usar o RAG para
/// pedir ajuda de resolucao logo depois de investigar um incidente.
Class Guardian.UI.RAGPage Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	// tSubmittedQuestion distingue "o usuario de fato mandou perguntar" de
	// "so estamos sugerindo um texto no campo" - so o primeiro deve disparar
	// Query.Ask (chamada real ao Gemini). Antes desta correcao, tQuestion
	// sozinho fazia os dois papeis: a sugestao automatica de pergunta (abaixo)
	// deixava tQuestion não-vazio mesmo sem o usuario ter clicado em nada, e
	// o "If (tQuestion '= "")" mais adiante disparava a consulta de qualquer
	// forma - so navegar para esta pagina apos uma investigacao ja acionava o
	// modelo de IA (lento) sem nenhum clique em "Perguntar".
	Set tSubmittedQuestion = $Get(%request.Data("q", 1))
	Set tQuestion = tSubmittedQuestion
	Set tHasAnswer = 0

	// Ultima investigacao feita no AI Incident Investigator (se houver) -
	// mesma tabela que Guardian.UI.InvestigatorPage grava. So leitura: se a
	// consulta falhar ou a tabela ainda nao tiver linhas, o RAG segue
	// funcionando normalmente sem o contexto.
	Set tHasInvestigation = 0
	Set tInvStmt = ##class(%SQL.Statement).%New()
	// CreatedAt convertido explicitamente para VARCHAR: %Get() num TIMESTAMP
	// devolve o valor logico interno (nao a string ODBC legivel) nesta
	// versao do IRIS - CAST forca a representacao de exibicao.
	Set tInvSC = tInvStmt.%Prepare(
		"SELECT TOP 1 Component, WindowMinutes, CAST(CreatedAt AS VARCHAR(30)) AS CreatedAt, Analysis " _
		"FROM Guardian_Investigator.Investigation ORDER BY CreatedAt DESC")
	If tInvSC = 1 {
		Set tInvRS = tInvStmt.%Execute()
		If tInvRS.%Next() {
			Set tHasInvestigation = 1
			Set tInvComponent = tInvRS.%Get("Component")
			Set tInvWindow = tInvRS.%Get("WindowMinutes")
			Set tInvCreatedAt = tInvRS.%Get("CreatedAt")
			Set tInvAnalysis = tInvRS.%Get("Analysis")
		}
	}

	// So sugere a pergunta quando o usuario ainda nao digitou nenhuma -
	// nunca sobrescreve o que a pessoa esta perguntando.
	If tHasInvestigation && (tQuestion = "") {
		Set tQuestion = ##class(Guardian.UI.I18n).T("rag.suggested_question") _ tInvComponent _ "?"
	}

	Set tHtmlLang = ##class(Guardian.UI.I18n).HtmlLang()
	Set tThemeAttr = ##class(Guardian.UI.I18n).ThemeAttr()

	&html<<!DOCTYPE html>
<html lang="#(tHtmlLang)#"#(tThemeAttr)#>
<head>
<meta charset="utf-8">
<title>IRIS Production Guardian - RAG Assistant</title>
<link rel="stylesheet" href="/csp/guardian/assets/css/iris-guardian-theme.css?v=2">
<style>
	main { max-width: 800px; margin: 0 auto; padding: 2rem 1.5rem; }
	h1 { color: var(--ig-on-bg-text); font-size: 1.4rem; margin-bottom: 1.5rem; }
	form { display: flex; gap: 0.5rem; margin-bottom: 1.5rem; }
	input[type=text] { flex: 1; padding: 0.6rem 0.8rem; border-radius: var(--ig-radius-sm); border: 1px solid var(--ig-border); background: var(--ig-surface); color: var(--ig-text); font-size: 1rem; }
	button { padding: 0.6rem 1.2rem; border-radius: var(--ig-radius-sm); border: none; background: var(--ig-teal-500); color: var(--ig-navy-900); font-weight: 600; cursor: pointer; }
	button:hover { background: var(--ig-teal-700); color: var(--ig-white); }
	.investigation-context { background: var(--ig-tint); border: 1px solid var(--ig-border); border-left: 4px solid var(--ig-teal-500); border-radius: var(--ig-radius-sm); padding: 0.85rem 1rem; margin-bottom: 1.25rem; font-size: 0.85rem; }
	.investigation-context .ic-title { font-weight: 600; color: var(--ig-teal-700); margin-bottom: 0.3rem; }
	.investigation-context .ic-meta { color: var(--ig-text-muted); font-size: 0.78rem; margin-bottom: 0.5rem; }
	.investigation-context .ic-analysis { white-space: pre-wrap; color: var(--ig-text); max-height: 160px; overflow-y: auto; }
	.answer-box { background: var(--ig-surface); border: 1px solid var(--ig-border); box-shadow: var(--ig-shadow); border-radius: var(--ig-radius); padding: 1.25rem; margin-bottom: 1.5rem; border-left: 4px solid var(--ig-teal-500); }
	.answer-box.abstained { border-left-color: var(--ig-status-unknown); }
	.answer-text { white-space: pre-wrap; line-height: 1.5; color: var(--ig-text); }
	.source { background: var(--ig-tint); border: 1px solid var(--ig-border); border-radius: var(--ig-radius-sm); padding: 0.75rem 1rem; margin-bottom: 0.5rem; font-size: 0.85rem; }
	.source .src-title { font-weight: 600; color: var(--ig-teal-700); }
	.source .src-sim { color: var(--ig-text-muted); float: right; }
	.source .src-text { color: var(--ig-text-muted); margin-top: 0.4rem; white-space: pre-wrap; }
	.note { font-size: 0.75rem; color: var(--ig-on-bg-muted); margin-top: 2rem; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 1rem; }
</style>
</head>
<body>
<div class="ig-shell">>

	Do ##class(Guardian.UI.Shared).RenderSidebar("rag")

	&html<<main class="ig-main">
<h1>RAG Assistant</h1>>

	If tHasInvestigation {
		Set tAnalysisFmt = $Select($Length(tInvAnalysis) > 600:$Extract(tInvAnalysis, 1, 600) _ "…", 1:tInvAnalysis)
		Set tWindowMeta = $Replace(##class(Guardian.UI.I18n).T("rag.window_meta"), "#N#", tInvWindow)
		&html<<div class="investigation-context">
	<div class="ic-title">#(##class(Guardian.UI.I18n).T("rag.investigation_context_title"))#</div>
	<div class="ic-meta">#(##class(Guardian.UI.I18n).T("rag.component_label"))# <strong>#(tInvComponent)#</strong> &middot; #(tWindowMeta)# &middot; #(tInvCreatedAt)#</div>
	<div class="ic-analysis">#(##class(Guardian.UI.Shared).FormatText(tAnalysisFmt))#</div>
</div>>
	}

	&html<<form method="get">
	<input type="text" name="q" placeholder="#(##class(Guardian.UI.I18n).T("rag.placeholder"))#" value="#(tQuestion)#" autofocus>
	<button type="submit" data-loading-text="#(##class(Guardian.UI.I18n).T("rag.submit_loading"))#">#(##class(Guardian.UI.I18n).T("rag.submit"))#</button>
</form>
<div class="ig-loading" id="ig-loading" hidden>
	<img src="/csp/guardian/iris-guardian-spinner.png" alt="" class="ig-loading-emblem">
	<span>#(##class(Guardian.UI.I18n).T("rag.loading_banner"))#</span>
</div>
<script>
(function () {
	var form = document.querySelector("form");
	if (!form) { return; }
	form.addEventListener("submit", function () {
		var btn = form.querySelector("button[type=submit]");
		if (!btn || btn.disabled) { return; }
		btn.disabled = true;
		btn.setAttribute("aria-busy", "true");
		btn.textContent = btn.getAttribute("data-loading-text") || "Processando...";
		btn.classList.add("ig-btn-loading");
		var loading = document.getElementById("ig-loading");
		if (loading) { loading.hidden = false; }
	});
})();
</script>>

	If (tSubmittedQuestion '= "") {
		Set tResp = ""
		Try {
			// Manda a analise COMPLETA da ultima investigacao (nao o resumo
			// truncado em 600 caracteres exibido acima, que existe so para a
			// pessoa ler na tela) - e nela que estao os PROXIMOS PASSOS
			// SUGERIDOS que respondem "como resolver".
			Set tInvContextForAsk = $Select(tHasInvestigation:tInvAnalysis, 1:"")
			Set tResp = ##class(Guardian.RAG.Query).Ask(tQuestion, tInvContextForAsk, ##class(Guardian.UI.I18n).Lang())
		} Catch ex {
			// Indisponibilidade do modelo de IA nao deve derrubar a pagina
			// nem esconder o problema - mostra o erro real, sem inventar
			// uma resposta.
			Set tResp = {}
			Set tResp.abstained = 1
			Set tResp.answer = ##class(Guardian.UI.I18n).T("rag.model_unavailable") _ ex.DisplayString() _ ##class(Guardian.UI.I18n).T("rag.model_unavailable_suffix")
			Set tResp.sources = []
		}
		Set tHasAnswer = 1
		Set tBoxClass = $Select(tResp.abstained:"answer-box abstained", 1:"answer-box")

		&html<<div class="#(tBoxClass)#">
	<div class="answer-text">#(##class(Guardian.UI.Shared).FormatText(tResp.answer))#</div>
</div>>

		If (tResp.abstained = 0) && (tResp.sources.%Size() > 0) {
			&html<<div class="sources"><strong>#(##class(Guardian.UI.I18n).T("rag.sources_used"))#</strong>>
			Set tIter = tResp.sources.%GetIterator()
			While tIter.%GetNext(.tKey, .tSrc) {
				Set tSimFmt = $FNumber(tSrc.similarity, "", 3)
				&html<<div class="source">
	<span class="src-sim">#(##class(Guardian.UI.I18n).T("rag.similarity"))# #(tSimFmt)#</span>
	<span class="src-title">#(##class(Guardian.UI.Shared).FormatText(tSrc.title))#</span> (#($ZConvert(tSrc.source, "O", "HTML"))#)
	<div class="src-text">#(##class(Guardian.UI.Shared).FormatText(tSrc.chunkText))#</div>
</div>>
			}
			&html<</div>>
		}
	}

	&html<<div class="note">
	#(##class(Guardian.UI.I18n).T("rag.note"))#
</div>>

	&html<</main>
</div>
</body>
</html>>

	Quit $$$OK
}

}

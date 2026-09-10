/// Pagina do RAG Assistant (Fase 3). So apresentacao aqui - recuperacao,
/// geracao, citacao e abstencao vem de Guardian.RAG.Query. Formulario
/// HTML simples (POST/GET), sem JS - a geracao pode levar alguns
/// segundos (modelo com raciocinio interno), entao um recarregamento de
/// pagina e mais robusto que uma chamada assincrona.
Class Guardian.UI.RAGPage Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	Set tQuestion = $Get(%request.Data("q", 1))
	Set tHasAnswer = 0

	&html<<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>IRIS Production Guardian - RAG Assistant</title>
<link rel="stylesheet" href="/csp/guardian/assets/css/iris-guardian-theme.css">
<style>
	.ig-page-header { display: flex; align-items: center; gap: 1.5rem; padding: 0.75rem 1.5rem; background: var(--ig-bg-strong); }
	.ig-logo-badge { background: var(--ig-white); border-radius: var(--ig-radius-sm); padding: 0.35rem 0.75rem; box-shadow: var(--ig-shadow); display: flex; }
	.ig-logo-badge img { height: 60px; width: auto; display: block; }
	.ig-page-header nav { display: flex; gap: 1.25rem; margin-left: auto; }
	.ig-page-header nav a { color: var(--ig-on-bg-muted); opacity: 1; text-decoration: none; font-size: 0.85rem; font-weight: 600; letter-spacing: 0.03em; text-transform: uppercase; padding-bottom: 2px; }
	.ig-page-header nav a:hover, .ig-page-header nav a[aria-current="page"] { color: var(--ig-on-bg-text); border-bottom: 2px solid var(--ig-teal-500); }
	main { max-width: 800px; margin: 0 auto; padding: 2rem 1.5rem; }
	h1 { color: var(--ig-on-bg-text); font-size: 1.4rem; margin-bottom: 1.5rem; }
	form { display: flex; gap: 0.5rem; margin-bottom: 1.5rem; }
	input[type=text] { flex: 1; padding: 0.6rem 0.8rem; border-radius: var(--ig-radius-sm); border: 1px solid var(--ig-border); background: var(--ig-surface); color: var(--ig-text); font-size: 1rem; }
	button { padding: 0.6rem 1.2rem; border-radius: var(--ig-radius-sm); border: none; background: var(--ig-teal-500); color: var(--ig-navy-900); font-weight: 600; cursor: pointer; }
	button:hover { background: var(--ig-teal-700); color: var(--ig-white); }
	.answer-box { background: var(--ig-surface); border: 1px solid var(--ig-border); box-shadow: var(--ig-shadow); border-radius: var(--ig-radius); padding: 1.25rem; margin-bottom: 1.5rem; border-left: 4px solid var(--ig-teal-500); }
	.answer-box.abstained { border-left-color: var(--ig-status-unknown); }
	.answer-text { white-space: pre-wrap; line-height: 1.5; color: var(--ig-text); }
	.source { background: var(--ig-tint); border: 1px solid var(--ig-border); border-radius: var(--ig-radius-sm); padding: 0.75rem 1rem; margin-bottom: 0.5rem; font-size: 0.85rem; }
	.source .src-title { font-weight: 600; color: var(--ig-teal-700); }
	.source .src-sim { color: var(--ig-text-muted); float: right; }
	.source .src-text { color: var(--ig-text-muted); margin-top: 0.4rem; }
	.note { font-size: 0.75rem; color: var(--ig-on-bg-muted); margin-top: 2rem; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 1rem; }
</style>
</head>
<body>
<header class="ig-page-header">
	<div class="ig-logo-badge"><img src="/csp/guardian/iris-guardian-logo-header.png" alt="IRIS Guardian"></div>
	<nav>
		<a href="Guardian.UI.MonitorPage.cls">Monitor</a>
		<a href="Guardian.UI.RAGPage.cls" aria-current="page">RAG Assistant</a>
	</nav>
</header>
<main>
<h1>RAG Assistant</h1>
<form method="get">
	<input type="text" name="q" placeholder="Pergunte sobre o projeto..." value="#(tQuestion)#" autofocus>
	<button type="submit">Perguntar</button>
</form>>

	If (tQuestion '= "") {
		Set tResp = ""
		Try {
			Set tResp = ##class(Guardian.RAG.Query).Ask(tQuestion)
		} Catch ex {
			// Indisponibilidade do modelo de IA nao deve derrubar a pagina
			// nem esconder o problema - mostra o erro real, sem inventar
			// uma resposta.
			Set tResp = {}
			Set tResp.abstained = 1
			Set tResp.answer = "Não foi possível consultar o modelo de IA agora (" _ ex.DisplayString() _ "). Tente novamente em instantes."
			Set tResp.sources = []
		}
		Set tHasAnswer = 1
		Set tBoxClass = $Select(tResp.abstained:"answer-box abstained", 1:"answer-box")

		&html<<div class="#(tBoxClass)#">
	<div class="answer-text">#(tResp.answer)#</div>
</div>>

		If (tResp.abstained = 0) && (tResp.sources.%Size() > 0) {
			&html<<div class="sources"><strong>Fontes usadas:</strong>>
			Set tIter = tResp.sources.%GetIterator()
			While tIter.%GetNext(.tKey, .tSrc) {
				Set tSimFmt = $FNumber(tSrc.similarity, "", 3)
				&html<<div class="source">
	<span class="src-sim">similaridade: #(tSimFmt)#</span>
	<span class="src-title">#(tSrc.title)#</span> (#(tSrc.source)#)
	<div class="src-text">#(tSrc.chunkText)#</div>
</div>>
			}
			&html<</div>>
		}
	}

	&html<<div class="note">
	Respostas geradas por IA (Google Gemini) a partir apenas dos documentos indexados deste projeto -
	nao inventa informacao fora do contexto recuperado, e responde "nao sei" quando a similaridade
	com a base e baixa. Limiar atual de abstencao: 0.58 (heuristica inicial, ver docs/planejamento/04_FASE_3_RAG_ASSISTANT.md).
</div>
</main>
</body>
</html>>

	Quit $$$OK
}

}

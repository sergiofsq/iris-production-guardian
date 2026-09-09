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
<style>
	body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; background: #0a1965; color: #eef1ff; margin: 0; padding: 2rem; }
	h1 { color: #0fd1c4; font-size: 1.5rem; margin-bottom: 1.5rem; }
	form { display: flex; gap: 0.5rem; margin-bottom: 1.5rem; max-width: 800px; }
	input[type=text] { flex: 1; padding: 0.6rem 0.8rem; border-radius: 6px; border: 1px solid #23306b; background: #102f8b; color: #eef1ff; font-size: 1rem; }
	button { padding: 0.6rem 1.2rem; border-radius: 6px; border: none; background: #0fd1c4; color: #0a1965; font-weight: 600; cursor: pointer; }
	.answer-box { background: #102f8b; border-radius: 8px; padding: 1.25rem; max-width: 800px; margin-bottom: 1.5rem; border-left: 4px solid #0fd1c4; }
	.answer-box.abstained { border-left-color: #7f8c8d; }
	.answer-text { white-space: pre-wrap; line-height: 1.5; }
	.sources { max-width: 800px; }
	.source { background: #0d2470; border-radius: 6px; padding: 0.75rem 1rem; margin-bottom: 0.5rem; font-size: 0.85rem; }
	.source .src-title { font-weight: 600; color: #9ee8e2; }
	.source .src-sim { color: #9aa4d6; float: right; }
	.source .src-text { color: #b7bde8; margin-top: 0.4rem; }
	.note { font-size: 0.75rem; color: #6f7ac0; max-width: 800px; margin-top: 2rem; border-top: 1px solid #23306b; padding-top: 1rem; }
</style>
</head>
<body>
<h1>IRIS Production Guardian &mdash; RAG Assistant</h1>
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
	com a base e baixa. Limiar atual de abstencao: 0.58 (heuristica inicial, ver 04_FASE_3_RAG_ASSISTANT.md).
</div>
</body>
</html>>

	Quit $$$OK
}

}

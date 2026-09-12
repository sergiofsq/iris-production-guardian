/// Segunda opcao de RAG Assistant (12/09/2026) - por enquanto uma copia
/// funcional identica de Guardian.UI.RAGPage (mesmo Guardian.RAG.Query,
/// mesmo backend Gemini), criada so para reservar o segundo item de menu
/// enquanto o provedor de LLM alternativo ainda nao foi escolhido. Quando
/// a decisao for tomada, so a chamada de geracao/embedding aqui precisa
/// trocar - retrieval, formulario e contexto de investigacao continuam
/// iguais aos de Guardian.UI.RAGPage.
Class Guardian.UI.RAGAltPage Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

ClassMethod OnPage() As %Status
{
	Set tQuestion = $Get(%request.Data("q", 1))
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
		Set tQuestion = "Como resolver o problema investigado em " _ tInvComponent _ "?"
	}

	&html<<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>IRIS Production Guardian - RAG Assistant (novo modelo)</title>
<link rel="stylesheet" href="/csp/guardian/assets/css/iris-guardian-theme.css">
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
	.source .src-text { color: var(--ig-text-muted); margin-top: 0.4rem; }
	.note { font-size: 0.75rem; color: var(--ig-on-bg-muted); margin-top: 2rem; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 1rem; }
</style>
</head>
<body>
<div class="ig-shell">>

	Do ##class(Guardian.UI.Shared).RenderSidebar("ragalt")

	&html<<main class="ig-main">
<h1>RAG Assistant (novo modelo)</h1>>

	If tHasInvestigation {
		Set tAnalysisFmt = $Select($Length(tInvAnalysis) > 600:$Extract(tInvAnalysis, 1, 600) _ "…", 1:tInvAnalysis)
		&html<<div class="investigation-context">
	<div class="ic-title">Contexto: última investigação (AI Incident Investigator)</div>
	<div class="ic-meta">Componente: <strong>#(tInvComponent)#</strong> &middot; janela #(tInvWindow)# min &middot; #(tInvCreatedAt)#</div>
	<div class="ic-analysis">#(tAnalysisFmt)#</div>
</div>>
	}

	&html<<form method="get">
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
	Placeholder do segundo provedor de LLM (ainda nao escolhido) - por enquanto
	responde com o mesmo backend do RAG Assistant (Gemini): apenas os documentos
	indexados deste projeto, sem inventar informacao fora do contexto recuperado,
	e responde "nao sei" quando a similaridade com a base e baixa. Limiar atual
	de abstencao: 0.58 (heuristica inicial, ver docs/planejamento/04_FASE_3_RAG_ASSISTANT.md).
</div>>

	&html<</main>
</div>
</body>
</html>>

	Quit $$$OK
}

}

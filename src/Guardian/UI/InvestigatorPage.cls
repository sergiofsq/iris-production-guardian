/// Pagina do AI Incident Investigator (Fase 4). So apresentacao aqui - a
/// coleta de evidencia vem de Guardian.Investigator.EvidenceCollector e a
/// analise de Guardian.Investigator.Analyzer. Formulario HTML simples
/// (GET, sem JS), mesmo padrao de Guardian.UI.RAGPage - a analise pode
/// levar alguns segundos, entao um recarregamento de pagina e mais
/// robusto que uma chamada assincrona.
Class Guardian.UI.InvestigatorPage Extends %CSP.Page
{

Parameter CHARSET = "utf-8";

/// Janela padrao quando o usuario nao especifica uma.
Parameter DefaultWindowMinutes = 60;

ClassMethod OnPage() As %Status
{
	Set tComponent = $Get(%request.Data("component", 1))
	Set tWindowMinutes = +$Get(%request.Data("window", 1), ..#DefaultWindowMinutes)
	If tWindowMinutes <= 0 {
		Set tWindowMinutes = ..#DefaultWindowMinutes
	}

	// Lista de componentes reais da Production monitorada, para o
	// formulario nao aceitar nome arbitrario - reaproveita StatusCollector,
	// mesma fonte de verdade do Monitor (Fase 2).
	Set tStatus = ##class(Guardian.Monitor.StatusCollector).Collect()

	&html<<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>IRIS Production Guardian - AI Incident Investigator</title>
<link rel="stylesheet" href="/csp/guardian/assets/css/iris-guardian-theme.css?v=2">
<style>
	main { max-width: 900px; margin: 0 auto; padding: 2rem 1.5rem; }
	h1 { color: var(--ig-on-bg-text); font-size: 1.4rem; margin-bottom: 0.25rem; }
	h2 { color: var(--ig-on-bg-text); font-size: 1rem; text-transform: uppercase; letter-spacing: 0.05em; margin: 1.5rem 0 0.75rem; }
	.subtitle { color: var(--ig-on-bg-muted); font-size: 0.85rem; margin-bottom: 1.5rem; }
	form { display: flex; gap: 0.5rem; margin-bottom: 1.5rem; flex-wrap: wrap; align-items: center; }
	select, input[type=number] { padding: 0.6rem 0.8rem; border-radius: var(--ig-radius-sm); border: 1px solid var(--ig-border); background: var(--ig-surface); color: var(--ig-text); font-size: 1rem; }
	label { color: var(--ig-on-bg-muted); font-size: 0.85rem; }
	button { padding: 0.6rem 1.2rem; border-radius: var(--ig-radius-sm); border: none; background: var(--ig-teal-500); color: var(--ig-navy-900); font-weight: 600; cursor: pointer; }
	button:hover { background: var(--ig-teal-700); color: var(--ig-white); }
	.card { background: var(--ig-surface); border: 1px solid var(--ig-border); box-shadow: var(--ig-shadow); border-radius: var(--ig-radius-sm); padding: 1rem; margin-bottom: 0.75rem; }
	.badge { display: inline-block; font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.05em; padding: 0.15rem 0.5rem; border-radius: 999px; font-weight: 600; }
	.badge.healthy { background: color-mix(in srgb, var(--ig-status-healthy) 15%, white); color: var(--ig-status-healthy); }
	.badge.degraded { background: color-mix(in srgb, var(--ig-status-degraded) 18%, white); color: var(--ig-status-degraded); }
	.badge.unavailable { background: color-mix(in srgb, var(--ig-status-down) 15%, white); color: var(--ig-status-down); }
	.badge.unknown { background: color-mix(in srgb, var(--ig-status-unknown) 18%, white); color: var(--ig-status-unknown); }
	.event { border-bottom: 1px solid var(--ig-border); padding: 0.5rem 0; font-size: 0.85rem; }
	.event:last-child { border-bottom: none; }
	.event .evt-meta { color: var(--ig-text-muted); }
	.event .evt-error { color: var(--ig-status-down); margin-top: 0.2rem; }
	.event .evt-ok { color: var(--ig-status-healthy); margin-top: 0.2rem; }
	.source { background: var(--ig-tint); border: 1px solid var(--ig-border); border-radius: var(--ig-radius-sm); padding: 0.75rem 1rem; margin-bottom: 0.5rem; font-size: 0.85rem; }
	.source .src-title { font-weight: 600; color: var(--ig-teal-700); }
	.source .src-sim { color: var(--ig-text-muted); float: right; }
	.source .src-text { color: var(--ig-text-muted); margin-top: 0.4rem; white-space: pre-wrap; }
	.answer-box { background: var(--ig-surface); border: 1px solid var(--ig-border); box-shadow: var(--ig-shadow); border-radius: var(--ig-radius); padding: 1.25rem; margin-bottom: 1.5rem; border-left: 4px solid var(--ig-teal-500); }
	.answer-box.unavailable { border-left-color: var(--ig-status-unknown); }
	.answer-text { white-space: pre-wrap; line-height: 1.5; color: var(--ig-text); }
	.empty { color: var(--ig-text-muted); font-size: 0.85rem; font-style: italic; }
	.note { font-size: 0.75rem; color: var(--ig-on-bg-muted); margin-top: 2rem; border-top: 1px solid rgba(255,255,255,0.2); padding-top: 1rem; }
</style>
</head>
<body>
<div class="ig-shell">>

	Do ##class(Guardian.UI.Shared).RenderSidebar("investigator")

	&html<<main class="ig-main">
<h1>AI Incident Investigator</h1>
<div class="subtitle">Evidência real (métricas, eventos e documentação) + análise assistida por IA. Só leitura - nenhuma remediação automática.</div>
<form method="get">
	<label for="component">Componente</label>
	<select name="component" id="component">
		<option value="">Selecione...</option>>

	Set tIter = tStatus.hosts.%GetIterator()
	While tIter.%GetNext(.tKey, .tHost) {
		Set tSelected = $Select(tHost.name = tComponent:" selected", 1:"")
		&html<<option value="#(tHost.name)#"#(tSelected)#>#(tHost.name)# (#(tHost.type)#)</option>>
	}

	&html<</select>
	<label for="window">Janela (minutos)</label>
	<input type="number" name="window" id="window" min="1" value="#(tWindowMinutes)#">
	<button type="submit" data-loading-text="Investigando...">Investigar</button>
</form>
<div class="ig-loading" id="ig-loading" hidden>
	<img src="/csp/guardian/iris-guardian-spinner.png" alt="" class="ig-loading-emblem">
	<span>Coletando evidência e analisando com IA... isso pode levar alguns segundos.</span>
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

	If (tComponent '= "") {
		Set tResult = ##class(Guardian.Investigator.Analyzer).Investigate(tComponent, tWindowMinutes)
		Set tEvidence = tResult.evidence

		// Persiste a investigacao para poder revisar depois (aceite do
		// contexto, secao 2: "persistir contexto suficiente para revisar
		// uma investigacao").
		Try {
			Set tInsStmt = ##class(%SQL.Statement).%New()
			Do tInsStmt.%Prepare(
				"INSERT INTO Guardian_Investigator.Investigation " _
				"(Component, WindowMinutes, CreatedAt, EventCount, DocumentCount, ModelAvailable, Analysis) " _
				"VALUES (?, ?, ?, ?, ?, ?, ?)")
			Do tInsStmt.%Execute(tComponent, tWindowMinutes, $ZDATETIME($Horolog, 3), tEvidence.eventCount, tEvidence.documents.%Size(), tResult.modelAvailable, tResult.analysis)
		} Catch ex {
			// Nao persistir a investigacao nao pode impedir mostrar o
			// resultado ao usuario - mesma filosofia de resiliencia das
			// demais paginas (indisponibilidade nao derruba a pagina).
		}

		&html<<h2>Saúde atual</h2>>
		If $IsObject(tEvidence.health) {
			&html<<div class="card">
	<span class="badge #(tEvidence.health.health)#">#(tEvidence.health.health)#</span>
	&nbsp; Fila: #(tEvidence.health.queueCount)# &middot;
	Mensagens: #(tEvidence.health.messageCount)# &middot;
	Erros recentes: #(tEvidence.health.recentErrorCount)#
</div>>
		} Else {
			&html<<div class="empty">Componente não encontrado na Production monitorada.</div>>
		}

		&html<<h2>Eventos na janela (#(tEvidence.eventCount)#)</h2>>
		If tEvidence.eventCount = 0 {
			&html<<div class="empty">Nenhum evento registrado nesta janela.</div>>
		} Else {
			&html<<div class="card">>
			Set tEvIter = tEvidence.events.%GetIterator()
			While tEvIter.%GetNext(.tEvKey, .tEv) {
				&html<<div class="event">
	<div class="evt-meta">msg ##(tEv.id)# &middot; #(tEv.timeCreated)# &middot; #(tEv.source)# &rarr; #(tEv.target)#</div>>
				If tEv.hasError {
					&html<<div class="evt-error">#($ZConvert(tEv.%Get("errorText"), "O", "HTML"))#</div>>
				} Else {
					&html<<div class="evt-ok">sucesso</div>>
				}
				&html<</div>>
			}
			&html<</div>>
		}

		&html<<h2>Análise</h2>>
		Set tBoxClass = $Select(tResult.modelAvailable:"answer-box", 1:"answer-box unavailable")
		&html<<div class="#(tBoxClass)#">
	<div class="answer-text">#(##class(Guardian.UI.Shared).FormatText(tResult.analysis))#</div>
</div>>

		&html<<h2>Documentação relacionada</h2>>
		If tEvidence.documents.%Size() = 0 {
			&html<<div class="empty">Nenhum documento relevante encontrado.</div>>
		} Else {
			Set tDocIter = tEvidence.documents.%GetIterator()
			While tDocIter.%GetNext(.tDocKey, .tDoc) {
				Set tSimFmt = $FNumber(tDoc.similarity, "", 3)
				&html<<div class="source">
	<span class="src-sim">similaridade: #(tSimFmt)#</span>
	<span class="src-title">#(##class(Guardian.UI.Shared).FormatText(tDoc.title))#</span> (#($ZConvert(tDoc.source, "O", "HTML"))#)
	<div class="src-text">#(##class(Guardian.UI.Shared).FormatText(tDoc.chunkText))#</div>
</div>>
			}
		}
	}

	&html<<div class="note">
	Análise gerada por IA (Google Gemini) a partir apenas da evidência real coletada acima -
	não inventa eventos nem percentual de confiança, e separa observação de hipótese. Investigação
	somente leitura - nenhuma correção é aplicada automaticamente.
</div>
</main>
</div>
</body>
</html>>

	Quit $$$OK
}

}
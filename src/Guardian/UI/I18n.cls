/// Internacionalizacao (12/09/2026): idioma da interface e' uma preferencia
/// do visitante (cookie "ig_lang", "pt" ou "en" - default "pt"), lida aqui e
/// usada tanto para o texto estatico das paginas (T()) quanto repassada aos
/// prompts de IA (Guardian.RAG.Query.Ask / Guardian.Investigator.Analyzer)
/// para que RESPOSTAS GERADAS tambem saiam no idioma escolhido - nao so os
/// rotulos da tela. O tema (claro/escuro) usa o mesmo padrao de cookie
/// ("ig_theme"), mas so precisa de CSS (ver iris-guardian-theme.css) - nao
/// tem texto para traduzir, entao fica so o helper ThemeAttr() aqui.
Class Guardian.UI.I18n Extends %RegisteredObject
{

/// Le a preferencia de idioma do cookie gravado pelo toggle (JS, ver
/// Guardian.UI.Shared.RenderSidebar) - sem cookie ou valor invalido, cai no
/// portugues (idioma original do projeto).
ClassMethod Lang() As %String
{
	Set tLang = %request.GetCookie("ig_lang", "pt")
	Quit $Select(tLang="en":"en", 1:"pt")
}

/// Valor pronto para o atributo lang="" da tag <html>.
ClassMethod HtmlLang() As %String
{
	Quit $Select(..Lang()="en":"en", 1:"pt-BR")
}

/// Atributo data-theme="dark" (ou string vazia p/ claro, o padrao) para a
/// tag <html> - lido do cookie "ig_theme" gravado pelo toggle. Precisa ser
/// decidido no servidor (nao so em JS) para a pagina ja nascer no tema
/// certo, sem "flash" de tema claro antes do JS rodar.
ClassMethod ThemeAttr() As %String
{
	Set tTheme = %request.GetCookie("ig_theme", "light")
	Quit $Select(tTheme="dark":" data-theme=""dark""", 1:"")
}

/// Traducao de uma chave de UI para o idioma atual. Chave desconhecida
/// devolve a propria chave (nunca quebra a pagina por texto faltando).
ClassMethod T(pKey As %String) As %String
{
	Do ..Dict(.d)
	Quit $Get(d(pKey, ..Lang()), pKey)
}

/// Rotulo traduzido para os codigos fixos de saude (healthy/degraded/
/// unavailable/unknown/stuck) usados como valor literal e tambem como nome
/// de classe CSS (".badge healthy" etc.) em Guardian.UI.MonitorPage e
/// Guardian.UI.InvestigatorPage - o CODIGO em si (e a classe CSS) continua
/// sempre em ingles (chave estavel usada em varios lugares), so o TEXTO
/// exibido ao lado muda com o idioma.
ClassMethod HealthLabel(pCode As %String) As %String
{
	Quit ..T("health."_pCode)
}

/// Dicionario pt/en - uma entrada por chave de UI. Mantido em um metodo so
/// (em vez de globals/arquivo externo) para ficar facil de revisar e casar
/// com o texto original de cada pagina.
ClassMethod Dict(ByRef d) [ Private ]
{
	// Sidebar (Guardian.UI.Shared)
	Set d("nav.monitor","pt")="Monitor", d("nav.monitor","en")="Monitor"
	Set d("nav.investigator","pt")="Investigator", d("nav.investigator","en")="Investigator"
	Set d("nav.rag","pt")="RAG Assistant (Gemini)", d("nav.rag","en")="RAG Assistant (Gemini)"
	Set d("nav.ragalt","pt")="RAG Assistant (novo modelo)", d("nav.ragalt","en")="RAG Assistant (new model)"
	Set d("sidebar.production_monitor","pt")="Production Monitor", d("sidebar.production_monitor","en")="Production Monitor"
	Set d("sidebar.no_hosts","pt")="Nenhum host ativo.", d("sidebar.no_hosts","en")="No active hosts."
	Set d("sidebar.details_link","pt")="Ver detalhes completos", d("sidebar.details_link","en")="View full details"
	Set d("sidebar.queue_word","pt")="fila", d("sidebar.queue_word","en")="queue"
	Set d("toggle.theme","pt")="Alternar tema claro/escuro", d("toggle.theme","en")="Toggle light/dark theme"
	Set d("toggle.lang","pt")="Mudar para inglês", d("toggle.lang","en")="Switch to Portuguese"

	// Estados de saude (codigo/classe CSS continuam em ingles - so o rotulo muda)
	Set d("health.healthy","pt")="saudável", d("health.healthy","en")="healthy"
	Set d("health.degraded","pt")="degradado", d("health.degraded","en")="degraded"
	Set d("health.unavailable","pt")="indisponível", d("health.unavailable","en")="unavailable"
	Set d("health.unknown","pt")="desconhecido", d("health.unknown","en")="unknown"
	Set d("health.stuck","pt")="travado", d("health.stuck","en")="stuck"

	// Guardian.UI.MonitorPage
	Set d("monitor.meta_production","pt")="Production:", d("monitor.meta_production","en")="Production:"
	Set d("monitor.meta_state","pt")="Estado:", d("monitor.meta_state","en")="State:"
	Set d("monitor.meta_collected","pt")="Coletado em:", d("monitor.meta_collected","en")="Collected at:"
	Set d("monitor.meta_refresh","pt")="(atualiza a cada 10s)", d("monitor.meta_refresh","en")="(refreshes every 10s)"
	Set d("monitor.col_service","pt")="Hosts de entrada (Service)", d("monitor.col_service","en")="Inbound hosts (Service)"
	Set d("monitor.col_process","pt")="Hosts de processamento (Process)", d("monitor.col_process","en")="Processing hosts (Process)"
	Set d("monitor.col_operation","pt")="Hosts de saída (Operation)", d("monitor.col_operation","en")="Outbound hosts (Operation)"
	Set d("monitor.queue","pt")="Fila:", d("monitor.queue","en")="Queue:"
	Set d("monitor.messages","pt")="Mensagens:", d("monitor.messages","en")="Messages:"
	Set d("monitor.recent_errors","pt")="Erros recentes:", d("monitor.recent_errors","en")="Recent errors:"
	Set d("monitor.trend","pt")="tendência de fila (#N# amostras):", d("monitor.trend","en")="queue trend (#N# samples):"
	Set d("monitor.no_hosts_type","pt")="Nenhum host deste tipo.", d("monitor.no_hosts_type","en")="No hosts of this type."
	Set d("monitor.legend","pt")="Estados: <strong>saudável</strong> = sem fila pendente e sem erro recente &middot; <strong>degradado</strong> = fila pendente ou erro nos últimos #WINDOW# segundos &middot; <strong>indisponível</strong> = host desabilitado ou Production parada &middot; <strong>desconhecido</strong> = nenhuma mensagem registrada ainda para este host (ausência de dado não é saúde) &middot; <strong>travado</strong> = fila positiva e sem esvaziar nas últimas 3 amostras persistidas. Série temporal persistida a cada carregamento desta página ou chamada da API (/api/guardian/status) - sem coletor agendado independente nesta v1."
	Set d("monitor.legend","en")="States: <strong>healthy</strong> = no pending queue and no recent error &middot; <strong>degraded</strong> = pending queue or error in the last #WINDOW# seconds &middot; <strong>unavailable</strong> = host disabled or Production stopped &middot; <strong>unknown</strong> = no message recorded yet for this host (absence of data is not health) &middot; <strong>stuck</strong> = positive queue that hasn't drained in the last 3 persisted samples. Time series persisted on each load of this page or API call (/api/guardian/status) - no independent scheduled collector in this v1."

	// Guardian.UI.InvestigatorPage
	Set d("investigator.subtitle","pt")="Evidência real (métricas, eventos e documentação) + análise assistida por IA. Só leitura - nenhuma remediação automática.", d("investigator.subtitle","en")="Real evidence (metrics, events and documentation) + AI-assisted analysis. Read-only - no automatic remediation."
	Set d("investigator.component_label","pt")="Componente", d("investigator.component_label","en")="Component"
	Set d("investigator.select","pt")="Selecione...", d("investigator.select","en")="Select..."
	Set d("investigator.window_label","pt")="Janela (minutos)", d("investigator.window_label","en")="Window (minutes)"
	Set d("investigator.submit","pt")="Investigar", d("investigator.submit","en")="Investigate"
	Set d("investigator.submit_loading","pt")="Investigando...", d("investigator.submit_loading","en")="Investigating..."
	Set d("investigator.loading_banner","pt")="Coletando evidência e analisando com IA... isso pode levar alguns segundos.", d("investigator.loading_banner","en")="Collecting evidence and analyzing with AI... this may take a few seconds."
	Set d("investigator.h2_health","pt")="Saúde atual", d("investigator.h2_health","en")="Current health"
	Set d("investigator.h2_events","pt")="Eventos na janela", d("investigator.h2_events","en")="Events in window"
	Set d("investigator.h2_analysis","pt")="Análise", d("investigator.h2_analysis","en")="Analysis"
	Set d("investigator.h2_docs","pt")="Documentação relacionada", d("investigator.h2_docs","en")="Related documentation"
	Set d("investigator.component_not_found","pt")="Componente não encontrado na Production monitorada.", d("investigator.component_not_found","en")="Component not found in the monitored Production."
	Set d("investigator.no_events","pt")="Nenhum evento registrado nesta janela.", d("investigator.no_events","en")="No events recorded in this window."
	Set d("investigator.success","pt")="sucesso", d("investigator.success","en")="success"
	Set d("investigator.no_docs","pt")="Nenhum documento relevante encontrado.", d("investigator.no_docs","en")="No relevant documents found."
	Set d("investigator.note","pt")="Análise gerada por IA (Google Gemini) a partir apenas da evidência real coletada acima - não inventa eventos nem percentual de confiança, e separa observação de hipótese. Investigação somente leitura - nenhuma correção é aplicada automaticamente.", d("investigator.note","en")="Analysis generated by AI (Google Gemini) using only the real evidence collected above - it does not invent events or a confidence percentage, and keeps observation separate from hypothesis. Read-only investigation - no correction is applied automatically."

	// Guardian.UI.RAGPage / RAGAltPage (chaves compartilhadas)
	Set d("rag.investigation_context_title","pt")="Contexto: última investigação (AI Incident Investigator)", d("rag.investigation_context_title","en")="Context: latest investigation (AI Incident Investigator)"
	Set d("rag.component_label","pt")="Componente:", d("rag.component_label","en")="Component:"
	Set d("rag.window_meta","pt")="janela #N# min", d("rag.window_meta","en")="#N# min window"
	Set d("rag.placeholder","pt")="Pergunte sobre o projeto...", d("rag.placeholder","en")="Ask about the project..."
	Set d("rag.submit","pt")="Perguntar", d("rag.submit","en")="Ask"
	Set d("rag.submit_loading","pt")="Perguntando...", d("rag.submit_loading","en")="Asking..."
	Set d("rag.loading_banner","pt")="Consultando a IA e os documentos indexados... isso pode levar alguns segundos.", d("rag.loading_banner","en")="Querying the AI and the indexed documents... this may take a few seconds."
	Set d("rag.sources_used","pt")="Fontes usadas:", d("rag.sources_used","en")="Sources used:"
	Set d("rag.similarity","pt")="similaridade:", d("rag.similarity","en")="similarity:"
	Set d("rag.suggested_question","pt")="Como resolver o problema investigado em ", d("rag.suggested_question","en")="How to resolve the issue investigated in "
	Set d("rag.model_unavailable","pt")="Não foi possível consultar o modelo de IA agora (", d("rag.model_unavailable","en")="Could not reach the AI model right now ("
	Set d("rag.model_unavailable_suffix","pt")="). Tente novamente em instantes.", d("rag.model_unavailable_suffix","en")="). Try again shortly."
	Set d("rag.note","pt")="Respostas geradas por IA (Google Gemini) a partir apenas dos documentos indexados deste projeto - não inventa informação fora do contexto recuperado, e responde ""não sei"" quando a similaridade com a base é baixa. Limiar atual de abstenção: 0.58 (heurística inicial, ver docs/planejamento/04_FASE_3_RAG_ASSISTANT.md).", d("rag.note","en")="Answers generated by AI (Google Gemini) using only the documents indexed for this project - it does not invent information outside the retrieved context, and answers ""I don't know"" when similarity with the corpus is low. Current abstention threshold: 0.58 (initial heuristic, see docs/planejamento/04_FASE_3_RAG_ASSISTANT.md)."
	Set d("ragalt.note","pt")="Placeholder do segundo provedor de LLM (ainda não escolhido) - por enquanto responde com o mesmo backend do RAG Assistant (Gemini): apenas os documentos indexados deste projeto, sem inventar informação fora do contexto recuperado, e responde ""não sei"" quando a similaridade com a base é baixa. Limiar atual de abstenção: 0.58 (heurística inicial, ver docs/planejamento/04_FASE_3_RAG_ASSISTANT.md).", d("ragalt.note","en")="Placeholder for the second LLM provider (not yet chosen) - for now it answers with the same backend as the RAG Assistant (Gemini): only the documents indexed for this project, without inventing information outside the retrieved context, and answers ""I don't know"" when similarity with the corpus is low. Current abstention threshold: 0.58 (initial heuristic, see docs/planejamento/04_FASE_3_RAG_ASSISTANT.md)."

	// Guardian.RAG.Query (resposta/abstencao geradas por IA)
	Set d("query.abstain","pt")="Não há informação suficiente na base indexada para responder com confiança a esta pergunta.", d("query.abstain","en")="There isn't enough information in the indexed corpus to answer this question with confidence."

	// Guardian.Investigator.Analyzer (analise gerada por IA)
	Set d("analyzer.unavailable_prefix","pt")="Não foi possível gerar a análise agora (", d("analyzer.unavailable_prefix","en")="Could not generate the analysis right now ("
	Set d("analyzer.unavailable_suffix","pt")="). A evidência coletada abaixo continua disponível para revisão manual.", d("analyzer.unavailable_suffix","en")="). The evidence collected below is still available for manual review."
	Quit
}

}

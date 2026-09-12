/// Analise do AI Incident Investigator (Fase 4): recebe a evidencia real
/// coletada por Guardian.Investigator.EvidenceCollector e pede ao modelo
/// de IA um resumo, hipoteses (separadas de observacao), lacunas e
/// proximos passos sugeridos - todos referenciando a evidencia fornecida.
/// Nao inventa percentual de confianca (regra do contexto, secao 2) e nao
/// executa nenhuma remediacao - somente leitura/analise.
Class Guardian.Investigator.Analyzer Extends %RegisteredObject
{

/// Investiga pComponent na janela de pWindowMinutes: junta evidencia real
/// e pede a analise ao modelo. Se o modelo falhar, a evidencia ainda e
/// retornada (requisito do aceite - indisponibilidade do modelo nao pode
/// impedir consultar a evidencia). Retorna um %DynamicObject:
/// {component, windowMinutes, evidence, modelAvailable, analysis}.
///
/// pLang ("pt" ou "en", default "pt"): idioma da analise gerada e da
/// mensagem de indisponibilidade - preferencia do visitante
/// (Guardian.UI.I18n), repassada aqui em vez de importada diretamente para
/// o pacote Investigator nao depender do pacote UI.
ClassMethod Investigate(pComponent As %String, pWindowMinutes As %Integer = 30, pLang As %String = "pt") As %DynamicObject
{
	Set tResult = {}
	Set tResult.component = pComponent
	Set tResult.windowMinutes = pWindowMinutes

	Set tEvidence = ##class(Guardian.Investigator.EvidenceCollector).Collect(pComponent, pWindowMinutes)
	Set tResult.evidence = tEvidence

	Set tPrompt = ..BuildPrompt(tEvidence, pLang)

	Try {
		Set tAnswerText = ##class(Guardian.RAG.GeminiClient).Generate(tPrompt)
		Set tResult.modelAvailable = 1
		Set tResult.analysis = tAnswerText
	} Catch ex {
		Set tResult.modelAvailable = 0
		Set tResult.analysis = $Select(pLang="en":
			"Could not generate the analysis right now (", 1:
			"Não foi possível gerar a análise agora (") _ ex.DisplayString() _ $Select(pLang="en":
			"). The evidence collected below is still available for manual review.", 1:
			"). A evidência coletada abaixo continua disponível para revisão manual.")
	}

	Quit tResult
}

/// Monta o prompt de analise a partir da evidencia real coletada -
/// separado em metodo proprio para poder testar/ajustar o texto sem
/// mexer no fluxo de Investigate.
ClassMethod BuildPrompt(pEvidence As %DynamicObject, pLang As %String = "pt") As %String
{
	Set tEn = (pLang = "en")

	If tEn {
		Set tText = "You are an incident investigation assistant for InterSystems IRIS. " _
			"Use ONLY the real evidence provided below - do not invent events, metrics or documents. " _
			"Never present a numeric confidence percentage (e.g. '85% certain') - you have no statistical basis for that. " _
			"Clearly separate OBSERVATION (what the evidence shows) from HYPOTHESIS (your possible interpretation) - correlation is not proof of root cause. " _
			"If the evidence is insufficient for any part of the analysis, say so explicitly instead of filling the gap with assumption. " _
			"Answer in English, even though field values below (component/status names) are technical identifiers, in this format: SUMMARY, OBSERVATIONS, HYPOTHESES, GAPS, SUGGESTED NEXT STEPS." _
			$Char(10, 10)
	} Else {
		Set tText = "Você é um assistente de investigação de incidentes para InterSystems IRIS. " _
			"Use APENAS a evidência real fornecida abaixo - não invente eventos, métricas ou documentos. " _
			"Nunca apresente um percentual de confiança numérico (ex. '85% de certeza') - você não tem base estatística para isso. " _
			"Separe claramente OBSERVAÇÃO (o que a evidência mostra) de HIPÓTESE (sua interpretação possível) - correlação não é prova de causa raiz. " _
			"Se a evidência for insuficiente para alguma parte da análise, diga isso explicitamente em vez de preencher a lacuna com suposição. " _
			"Responda em português, no formato: RESUMO, OBSERVAÇÕES, HIPÓTESES, LACUNAS, PRÓXIMOS PASSOS SUGERIDOS." _
			$Char(10, 10)
	}

	Set tText = tText _ $Select(tEn:"COMPONENT: ", 1:"COMPONENTE: ") _ pEvidence.component _ $Char(10)
	Set tText = tText _ $Select(tEn:"WINDOW: last ", 1:"JANELA: últimos ") _ pEvidence.windowMinutes _ $Select(tEn:" minutes", 1:" minutos") _ $Char(10, 10)

	If $IsObject(pEvidence.health) {
		Set tText = tText _ $Select(tEn:"CURRENT HEALTH: ", 1:"SAÚDE ATUAL: ") _ pEvidence.health.health _
			$Select(tEn:" (queue=", 1:" (fila=") _ pEvidence.health.queueCount _
			$Select(tEn:", messages=", 1:", mensagens=") _ pEvidence.health.messageCount _
			$Select(tEn:", recent errors=", 1:", erros recentes=") _ pEvidence.health.recentErrorCount _ ")" _ $Char(10, 10)
	} Else {
		Set tText = tText _ $Select(tEn:
			"CURRENT HEALTH: component not found in the monitored Production.", 1:
			"SAÚDE ATUAL: componente não encontrado na Production monitorada.") _ $Char(10, 10)
	}

	Set tText = tText _ $Select(tEn:"REAL EVENTS (", 1:"EVENTOS REAIS (") _ pEvidence.eventCount _ $Select(tEn:" in window, most recent first):", 1:" na janela, mais recentes primeiro):") _ $Char(10)
	If pEvidence.eventCount = 0 {
		Set tText = tText _ $Select(tEn:"(no events recorded in this window)", 1:"(nenhum evento registrado nesta janela)") _ $Char(10)
	} Else {
		Set tIter = pEvidence.events.%GetIterator()
		While tIter.%GetNext(.tKey, .tEv) {
			Set tLine = "- [msg #" _ tEv.id _ ", " _ tEv.timeCreated _ "] " _ tEv.source _ " -> " _ tEv.target
			If tEv.hasError {
				Set tLine = tLine _ $Select(tEn:" | ERROR: ", 1:" | ERRO: ") _ tEv.%Get("errorText")
			} Else {
				Set tLine = tLine _ $Select(tEn:" | success", 1:" | sucesso")
			}
			Set tText = tText _ tLine _ $Char(10)
		}
	}
	Set tText = tText _ $Char(10)

	Set tText = tText _ $Select(tEn:"RELATED DOCUMENTATION (retrieved from the indexed corpus):", 1:"DOCUMENTAÇÃO RELACIONADA (recuperada do corpus indexado):") _ $Char(10)
	If pEvidence.documents.%Size() = 0 {
		Set tText = tText _ $Select(tEn:"(no relevant document found)", 1:"(nenhum documento relevante encontrado)") _ $Char(10)
	} Else {
		Set tIter2 = pEvidence.documents.%GetIterator()
		While tIter2.%GetNext(.tKey2, .tDoc) {
			Set tText = tText _ "[" _ $Select(tEn:"Source: ", 1:"Fonte: ") _ tDoc.title _ " (" _ tDoc.source _ ")]" _ $Char(10) _ tDoc.chunkText _ $Char(10, 10)
		}
	}

	Quit tText
}

}

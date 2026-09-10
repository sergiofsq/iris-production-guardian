/// Coleta de evidencia real para o AI Incident Investigator (Fase 4):
/// saude atual (reaproveita Guardian.Monitor.StatusCollector, sem
/// duplicar logica de saude), eventos reais de Ens.MessageHeader na
/// janela pedida (com o texto de erro legivel via
/// $System.Status.GetErrorText - verificado ao vivo em 10/09/2026 que
/// converte o valor bruto armazenado em ErrorStatus) e documentacao
/// relevante (reaproveita Guardian.RAG.Query.Retrieve, busca hibrida da
/// Fase 3, sem geracao). So leitura - nenhuma remediacao aqui.
Class Guardian.Investigator.EvidenceCollector Extends %RegisteredObject
{

/// Quantos eventos (mensagens) trazer no maximo, mais recentes primeiro -
/// evita estourar o prompt de analise com uma janela muito cheia.
Parameter MaxEvents = 20;

/// Junta evidencia real para pComponent (nome do host, ex.
/// "Guardian.Operation.FileOutputOperation") na janela de
/// pWindowMinutes. Retorna um %DynamicObject:
/// {component, windowMinutes, collectedAt, health, events:[...],
///  eventCount, documents:[...]}.
ClassMethod Collect(pComponent As %String, pWindowMinutes As %Integer = 30) As %DynamicObject
{
	Set tResult = {}
	Set tResult.component = pComponent
	Set tResult.windowMinutes = pWindowMinutes
	Set tResult.collectedAt = $ZDATETIME($Horolog, 3)

	// Saude atual do componente - reaproveita Guardian.Monitor.StatusCollector
	// (mesma logica de healthy/degraded/unavailable/unknown da Fase 2, nao
	// duplicada aqui).
	Set tResult.health = $$$NULLOREF
	Set tStatus = ##class(Guardian.Monitor.StatusCollector).Collect()
	Set tIter = tStatus.hosts.%GetIterator()
	While tIter.%GetNext(.tKey, .tHost) {
		If tHost.name = pComponent {
			Set tResult.health = tHost
			Quit
		}
	}

	// Cutoff da janela de tempo. Decompoe a janela inteira em dias+segundos
	// antes de subtrair - uma janela de mais de 1 dia (ex. investigar algo
	// de alguns dias atras) quebrava $ZDATETIME com <ILLEGAL VALUE> na
	// versao anterior, que so tratava rollover de exatamente 1 dia
	// (suficiente para o ErrorWindowSeconds fixo do Monitor, mas nao para
	// uma janela configuravel pelo usuario aqui) - encontrado testando ao
	// vivo com uma janela grande em 10/09/2026.
	Set tWindowSeconds = pWindowMinutes * 60
	Set tWindowDays = tWindowSeconds \ 86400
	Set tWindowSecsRem = tWindowSeconds # 86400
	Set tDays = $Piece($Horolog, ",", 1) - tWindowDays
	Set tSecs = $Piece($Horolog, ",", 2) - tWindowSecsRem
	If tSecs < 0 {
		Set tSecs = tSecs + 86400
		Set tDays = tDays - 1
	}
	Set tCutoff = $ZDATETIME(tDays_","_tSecs, 3)

	// Eventos reais (Ens.MessageHeader) na janela, mais recentes primeiro.
	// ErrorStatus = 1 e sucesso (verificado ao vivo em 10/09/2026 contra
	// mensagens reais); qualquer outro valor e um %Status de erro serializado,
	// convertido para texto legivel via GetErrorText.
	Set tEvents = []
	Set tErrorTexts = ""
	Set tStmt = ##class(%SQL.Statement).%New()
	Do tStmt.%Prepare(
		"SELECT TOP "_..#MaxEvents_" ID, SourceConfigName, TargetConfigName, ErrorStatus, TimeCreated " _
		"FROM Ens.MessageHeader WHERE (SourceConfigName = ? OR TargetConfigName = ?) AND TimeCreated > ? " _
		"ORDER BY TimeCreated DESC")
	Set tRS = tStmt.%Execute(pComponent, pComponent, tCutoff)
	While tRS.%Next() {
		Set tEv = {}
		Set tEv.id = tRS.%Get("ID")
		Set tEv.source = tRS.%Get("SourceConfigName")
		Set tEv.target = tRS.%Get("TargetConfigName")
		Set tEv.timeCreated = tRS.%Get("TimeCreated")

		Set tRawErr = tRS.%Get("ErrorStatus")
		Set tHasError = (tRawErr '= 1)
		Set tEv.hasError = tHasError
		If tHasError {
			Set tErrText = $System.Status.GetErrorText(tRawErr)
			Set tEv.errorText = tErrText
			Set tErrorTexts = tErrorTexts _ tErrText _ " "
		}
		Do tEvents.%Push(tEv)
	}
	Set tResult.events = tEvents
	Set tResult.eventCount = tEvents.%Size()

	// Documentacao relevante via busca hibrida do RAG (so recuperacao, sem
	// geracao - a geracao e feita uma unica vez, no Analyzer, sobre toda a
	// evidencia junta). Consulta o componente e, se houver, o texto real
	// dos erros encontrados - assim um erro especifico (ex. "#5005") tende
	// a puxar a documentacao certa mesmo que a similaridade semantica pura
	// fosse mediana (mesmo raciocinio da fusao hibrida da Fase 3).
	Set tDocs = []
	Set tDocQuery = pComponent
	If tErrorTexts '= "" {
		Set tDocQuery = pComponent _ " " _ tErrorTexts
	}
	Try {
		Set tRet = ##class(Guardian.RAG.Query).Retrieve(tDocQuery)
		Set tIter2 = tRet.sources.%GetIterator()
		While tIter2.%GetNext(.tKey2, .tSrc) {
			Do tDocs.%Push(tSrc)
		}
	} Catch ex {
		// Indisponibilidade do modelo de embeddings nao pode impedir a
		// consulta das demais evidencias (metricas/eventos) - requisito
		// explicito do aceite do Investigator (contexto secao 2: "nao
		// exibir percentuais de confianca inventados" e "indisponibilidade
		// do modelo nao impede consultar as evidencias").
	}
	Set tResult.documents = tDocs

	Quit tResult
}

}

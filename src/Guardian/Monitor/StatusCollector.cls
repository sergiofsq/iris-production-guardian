/// Logica compartilhada de coleta de estado da Production (Fase 2).
/// Chamada tanto pelo REST (Guardian.API.MonitorAPI) quanto pela pagina
/// HTML (Guardian.UI.MonitorPage) - uma unica implementacao das regras de
/// saude, documentadas em docs/planejamento/03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md
/// secao 3. Nao ha logica de negocio duplicada no navegador nem na pagina.
Class Guardian.Monitor.StatusCollector Extends %RegisteredObject
{

/// Nome fixo da production monitorada nesta v1 (uma unica production por
/// namespace neste projeto).
Parameter Production = "Guardian.Production.GuardianProduction";

/// Janela de deteccao de erro recente, em segundos (15 min = mesmo valor
/// do FailureTimeout padrao observado em Ens.BusinessOperation).
/// Nome sem underscore de proposito: "..#NOME_COM_UNDERSCORE" quebra o
/// parser do compilador (o "_" e o operador de concatenacao e interfere
/// na resolucao da referencia ao parametro) - confirmado empiricamente
/// durante o desenvolvimento desta classe.
Parameter ErrorWindowSeconds = 900;

/// Retorna um %DynamicObject com o estado da Production e de cada host.
ClassMethod Collect() As %DynamicObject
{
	Set tResult = {}

	// tProdState e' so para exibicao (Ens.Director localiza esse texto
	// conforme o idioma do navegador - "Running" vira "Em execucao" em
	// pt-BR). A decisao de saude usa IsProductionRunning, que retorna um
	// %Boolean real, independente de idioma - comparar a string localizada
	// contra "Running" foi um bug real encontrado nesta v1 (todo host
	// aparecia "unavailable" quando acessado em portugues).
	Do ##class(Ens.Director).GetProductionSummary(.tInfo)
	Set tProdEntry = $Get(tInfo(..#Production))
	Set tProdState = $Select(tProdEntry'="":$List(tProdEntry,1), 1:"")

	// IsProductionRunning devolve o nome da production ativa por parametro
	// de saida (nao aceita nome como filtro de entrada, apesar da aparencia
	// - confirmado testando as duas formas). Conferimos que a que esta
	// rodando e' de fato a nossa, nao so "alguma coisa está rodando".
	Set tAnyRunning = ##class(Ens.Director).IsProductionRunning(.tRunningProdName)
	Set tProdRunning = tAnyRunning && (tRunningProdName = ..#Production)

	Set tResult.production = ..#Production
	Set tResult.productionState = tProdState
	Set tResult.collectedAt = $ZDATETIME($Horolog, 3)

	Set tHosts = []

	Set tStmt = ##class(%SQL.Statement).%New()
	Set tSC = tStmt.%Prepare(
		"SELECT Item.Name AS Name, Item.ClassName AS ClassName, Item.Enabled AS Enabled " _
		"FROM Ens_Config.Item AS Item, Ens_Config.Production AS Prod " _
		"WHERE Item.Production = Prod.ID AND Prod.Name = ? ORDER BY Item.Name")
	If $$$ISERR(tSC) {
		Set tResult.hosts = tHosts
		Set tResult.error = $System.Status.GetErrorText(tSC)
		Quit tResult
	}

	Set tRS = tStmt.%Execute(..#Production)

	// Cutoff para "erro recente" (janela de ErrorWindowSeconds)
	Set tDays = $Piece($Horolog, ",", 1)
	Set tSecs = $Piece($Horolog, ",", 2) - ..#ErrorWindowSeconds
	If tSecs < 0 {
		Set tSecs = tSecs + 86400
		Set tDays = tDays - 1
	}
	Set tCutoff = $ZDATETIME(tDays_","_tSecs, 3)

	While tRS.%Next() {
		Set tName = tRS.%Get("Name")
		Set tClassName = tRS.%Get("ClassName")
		Set tEnabled = tRS.%Get("Enabled")

		Set tType = "Unknown"
		If $classmethod(tClassName, "%IsA", "Ens.BusinessService") {
			Set tType = "Service"
		} ElseIf $classmethod(tClassName, "%IsA", "Ens.BusinessProcess") {
			Set tType = "Process"
		} ElseIf $classmethod(tClassName, "%IsA", "Ens.BusinessOperation") {
			Set tType = "Operation"
		}

		Set tQueueCount = +##class(Ens.Queue).GetCount(tName)

		Set tMsgStmt = ##class(%SQL.Statement).%New()
		Do tMsgStmt.%Prepare(
			"SELECT COUNT(*) AS N FROM Ens.MessageHeader WHERE (SourceConfigName = ? OR TargetConfigName = ?)")
		Set tMsgRS = tMsgStmt.%Execute(tName, tName)
		Do tMsgRS.%Next()
		Set tMessageCount = +tMsgRS.%Get("N")

		Set tErrStmt = ##class(%SQL.Statement).%New()
		Do tErrStmt.%Prepare(
			"SELECT COUNT(*) AS N FROM Ens.MessageHeader WHERE (SourceConfigName = ? OR TargetConfigName = ?) AND ErrorStatus <> 1 AND TimeCreated > ?")
		Set tErrRS = tErrStmt.%Execute(tName, tName, tCutoff)
		Do tErrRS.%Next()
		Set tRecentErrorCount = +tErrRS.%Get("N")

		// Regras de saude - ver docs/planejamento/03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md secao 3
		If ('tProdRunning) || ('tEnabled) {
			Set tHealth = "unavailable"
		} ElseIf (tMessageCount = 0) {
			Set tHealth = "unknown"
		} ElseIf (tQueueCount > 0) || (tRecentErrorCount > 0) {
			Set tHealth = "degraded"
		} Else {
			Set tHealth = "healthy"
		}

		Set tHost = {}
		Set tHost.name = tName
		Set tHost.className = tClassName
		Set tHost.type = tType
		Set tHost.enabled = tEnabled
		Set tHost.queueCount = tQueueCount
		Set tHost.messageCount = tMessageCount
		Set tHost.recentErrorCount = tRecentErrorCount
		Set tHost.health = tHealth
		Do tHosts.%Push(tHost)
	}

	Set tResult.hosts = tHosts
	Set tResult.errorWindowSeconds = ..#ErrorWindowSeconds

	Quit tResult
}

}

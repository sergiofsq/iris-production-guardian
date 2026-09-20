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

/// Janela de deteccao de erro recente, em segundos. Igual ao valor real
/// do FailureTimeout padrao de Ens.BusinessOperation (15s, confirmado ao
/// vivo, nao presumido) - ate 19/09/2026 este parametro estava em 900
/// (15 minutos), um bug de unidade: o comentario original pretendia
/// "o mesmo valor do FailureTimeout" mas confundiu o numero 15 (segundos)
/// com 15 minutos. Corrigido para bater com o tempo real que o framework
/// usa para desistir de uma tentativa.
/// Nome sem underscore de proposito: "..#NOME_COM_UNDERSCORE" quebra o
/// parser do compilador (o "_" e o operador de concatenacao e interfere
/// na resolucao da referencia ao parametro) - confirmado empiricamente
/// durante o desenvolvimento desta classe.
Parameter ErrorWindowSeconds = 15;

/// Quantas amostras consecutivas (incluindo a atual) precisam ter fila
/// positiva e nao-decrescente para o host ser marcado como "travado" -
/// ver StuckWindow abaixo. Reforco de 10/09/2026 (serie temporal
/// persistida), ver docs/planejamento/03_FASE_2_PRODUCTION_MONITOR_WSGI_TELEMETRY.md.
Parameter StuckWindow = 3;

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

	// Guardados em baldes por tipo durante a coleta (abaixo) e concatenados
	// nesta ordem fixa (Service -> Process -> Operation, o fluxo real de uma
	// mensagem entrando/saindo) antes de devolver em tResult.hosts - sem
	// isso, a ordem vinha de "ORDER BY Item.Name" (alfabetica), que a
	// sidebar (Guardian.UI.Shared.RenderSidebar) exibe direto, sem reagrupar
	// por tipo como Guardian.UI.MonitorPage ja faz na pagina detalhada.
	Set tServiceHosts = []
	Set tProcessHosts = []
	Set tOperationHosts = []
	Set tOtherHosts = []

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

		// Persiste a amostra para a serie temporal (reforco de 10/09/2026) -
		// isolado em Try/Catch: falha ao gravar a amostra nao pode derrubar
		// a exibicao do estado atual, mesma filosofia de resiliencia ja
		// usada no RAG e no Investigator.
		Try {
			Set tInsStmt = ##class(%SQL.Statement).%New()
			Do tInsStmt.%Prepare(
				"INSERT INTO Guardian_Monitor.HealthSample " _
				"(Component, Health, QueueCount, MessageCount, RecentErrorCount, CollectedAt) " _
				"VALUES (?, ?, ?, ?, ?, ?)")
			Do tInsStmt.%Execute(tName, tHealth, tQueueCount, tMessageCount, tRecentErrorCount, $ZDATETIME($Horolog, 3))
		} Catch ex {
		}

		Set tStuck = ..IsStuck(tName)

		Set tHost = {}
		Set tHost.name = tName
		Set tHost.className = tClassName
		Set tHost.type = tType
		Set tHost.enabled = tEnabled
		Set tHost.queueCount = tQueueCount
		Set tHost.messageCount = tMessageCount
		Set tHost.recentErrorCount = tRecentErrorCount
		Set tHost.health = tHealth
		Set tHost.stuck = tStuck

		If tType = "Service" {
			Do tServiceHosts.%Push(tHost)
		} ElseIf tType = "Process" {
			Do tProcessHosts.%Push(tHost)
		} ElseIf tType = "Operation" {
			Do tOperationHosts.%Push(tHost)
		} Else {
			Do tOtherHosts.%Push(tHost)
		}
	}

	Set tHosts = []
	For tBucket = tServiceHosts, tProcessHosts, tOperationHosts, tOtherHosts {
		Set tIter = tBucket.%GetIterator()
		While tIter.%GetNext(.tKey, .tHost) {
			Do tHosts.%Push(tHost)
		}
	}

	Set tResult.hosts = tHosts
	Set tResult.errorWindowSeconds = ..#ErrorWindowSeconds

	Quit tResult
}

/// Um host esta "travado" se as ultimas StuckWindow amostras persistidas
/// (mais recente incluida) tem fila positiva e nao-decrescente ao longo
/// do tempo - ou seja, a fila nao esta esvaziando, nao e so uma foto de
/// um instante com fila > 0. Com menos amostras que StuckWindow ainda
/// nao ha historico suficiente, entao retorna falso (nao presumir
/// travamento sem dado real). Ordena por ID (ordem real de insercao), nao
/// por CollectedAt - $ZDATETIME($Horolog,3) so tem granularidade de 1
/// segundo, entao amostras inseridas na mesma janela de 1s (ex. num
/// teste automatizado, ou paginas carregadas rapido em sequencia) podiam
/// empatar em CollectedAt e sair fora de ordem - bug real encontrado
/// testando com dados controlados em 10/09/2026. Metodo proprio (nao
/// inline em Collect) para poder testar o algoritmo isoladamente.
ClassMethod IsStuck(pComponent As %String) As %Boolean
{
	Set tStuck = 0
	Try {
		Set tTrendStmt = ##class(%SQL.Statement).%New()
		Do tTrendStmt.%Prepare(
			"SELECT TOP "_..#StuckWindow_" QueueCount FROM Guardian_Monitor.HealthSample " _
			"WHERE Component = ? ORDER BY ID DESC")
		Set tTrendRS = tTrendStmt.%Execute(pComponent)
		Set tN = 0, tAllPositive = 1, tNonDecreasing = 1, tPrev = ""
		While tTrendRS.%Next() {
			Set tN = tN + 1
			Set tQ = +tTrendRS.%Get("QueueCount")
			If tQ <= 0 {
				Set tAllPositive = 0
			}
			If (tPrev '= "") && (tQ > tPrev) {
				// tPrev e a amostra mais recente que esta (percorrendo
				// DESC); um valor MAIOR que o anterior nesta ordem
				// significa que a fila estava crescendo indo para o
				// passado, ou seja, caindo com o tempo - fila esvaziando.
				Set tNonDecreasing = 0
			}
			Set tPrev = tQ
		}
		If (tN >= ..#StuckWindow) && tAllPositive && tNonDecreasing {
			Set tStuck = 1
		}
	} Catch ex {
	}
	Quit tStuck
}

/// Ultimas pLimit amostras de Component, mais antiga primeiro (para
/// exibir uma tendencia cronologica). Retorna um %DynamicObject (array
/// de {health, queueCount, messageCount, recentErrorCount, collectedAt}).
ClassMethod RecentSamples(pComponent As %String, pLimit As %Integer = 10) As %DynamicObject
{
	Set tSamples = []
	Set tStmt = ##class(%SQL.Statement).%New()
	Do tStmt.%Prepare(
		"SELECT TOP ? Health, QueueCount, MessageCount, RecentErrorCount, CollectedAt " _
		"FROM Guardian_Monitor.HealthSample WHERE Component = ? ORDER BY ID DESC")
	Set tRS = tStmt.%Execute(pLimit, pComponent)
	Set tRows = 0
	While tRS.%Next() {
		Set tRows = tRows + 1
		Set tS = {}
		Set tS.health = tRS.%Get("Health")
		Set tS.queueCount = tRS.%Get("QueueCount")
		Set tS.messageCount = tRS.%Get("MessageCount")
		Set tS.recentErrorCount = tRS.%Get("RecentErrorCount")
		Set tS.collectedAt = tRS.%Get("CollectedAt")
		Do tSamples.%Push(tS)
	}
	// Veio mais recente->mais antigo (ORDER BY DESC); inverte para
	// cronologico (mais antigo->mais recente), mais natural para exibir
	// uma tendencia.
	Set tChrono = []
	For tI = tSamples.%Size():-1:1 {
		Do tChrono.%Push(tSamples.%Get(tI-1))
	}
	Quit tChrono
}

}

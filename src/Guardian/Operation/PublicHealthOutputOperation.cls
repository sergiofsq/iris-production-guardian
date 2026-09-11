/// Business Operation do bonus API publica (+2): unica dona da tabela
/// Guardian_PublicHealth.Snapshot. Decide, a cada mensagem recebida do
/// Service de polling, se grava um dado ao vivo, se cai para o ultimo
/// valor real conhecido (cache, rotulado como tal e com idade calculada)
/// ou se marca indisponibilidade honesta (sem inventar numero).
Class Guardian.Operation.PublicHealthOutputOperation Extends Ens.BusinessOperation
{

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
	<MapItem MessageType="Guardian.Messages.PublicHealthSnapshot">
		<Method>SaveSnapshot</Method>
	</MapItem>
</MapItems>
}

/// Total de segundos "tipo horolog" (dias*86400 + segundos do dia) - mesma
/// convencao de aritmetica de tempo ja usada em Guardian.Investigator.EvidenceCollector,
/// evita depender de funcao SQL de diff nao confirmada no ambiente.
ClassMethod NowTotalSecs() As %Integer
{
	Quit ($Piece($Horolog, ",", 1) * 86400) + $Piece($Horolog, ",", 2)
}

Method SaveSnapshot(pRequest As Guardian.Messages.PublicHealthSnapshot, Output pResponse As %RegisteredObject) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tNowTotalSecs = ..NowTotalSecs()
		Set tNowDisplay = $ZDATETIME($Horolog, 3)

		If 'pRequest.FetchFailed {
			Set tSC = ..Insert(pRequest.Source, tNowDisplay, tNowTotalSecs, pRequest.UpdatedEpochMs,
				pRequest.CasesTotal, pRequest.DeathsTotal, pRequest.RecoveredTotal, pRequest.ActiveTotal, pRequest.CriticalTotal,
				0, 0, 0, "ao vivo")
			Quit
		}

		// Falha no poll: procura o ultimo dado real conhecido (ao vivo ou
		// cache repassado - nunca uma linha ja marcada indisponivel), para
		// nao inventar numero nem "esquecer" o dado de quando ele estava
		// vivo (a idade do cache cresce a partir do FetchedAt ORIGINAL).
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare(
			"SELECT TOP 1 Source, FetchedAt, FetchedAtTotalSecs, UpdatedEpochMs, " _
			"CasesTotal, DeathsTotal, RecoveredTotal, ActiveTotal, CriticalTotal " _
			"FROM Guardian_PublicHealth.Snapshot WHERE Unavailable = 0 ORDER BY ID DESC")
		Set tRS = tStmt.%Execute()

		If tRS.%Next() {
			Set tAgeSecs = tNowTotalSecs - tRS.%Get("FetchedAtTotalSecs")
			Set tNote = "cache ("_tAgeSecs_"s atras) - fonte indisponivel agora (http="_pRequest.HttpStatus_")"
			Set tSC = ..Insert(tRS.%Get("Source"), tRS.%Get("FetchedAt"), tRS.%Get("FetchedAtTotalSecs"), tRS.%Get("UpdatedEpochMs"),
				tRS.%Get("CasesTotal"), tRS.%Get("DeathsTotal"), tRS.%Get("RecoveredTotal"), tRS.%Get("ActiveTotal"), tRS.%Get("CriticalTotal"),
				1, tAgeSecs, 0, tNote)
		} Else {
			Set tNote = "indisponivel - sem cache disponivel ainda (http="_pRequest.HttpStatus_")"
			Set tSC = ..Insert(pRequest.Source, tNowDisplay, tNowTotalSecs, "", "", "", "", "", "", 0, 0, 1, tNote)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

ClassMethod Insert(pSource, pFetchedAt, pFetchedAtTotalSecs, pUpdatedEpochMs, pCases, pDeaths, pRecovered, pActive, pCritical, pFromCache, pCacheAgeSeconds, pUnavailable, pNote) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare(
			"INSERT INTO Guardian_PublicHealth.Snapshot (" _
			"Source, FetchedAt, FetchedAtTotalSecs, UpdatedEpochMs, " _
			"CasesTotal, DeathsTotal, RecoveredTotal, ActiveTotal, CriticalTotal, " _
			"FromCache, CacheAgeSeconds, Unavailable, Note) " _
			"VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
		Set tRS = tStmt.%Execute(pSource, pFetchedAt, pFetchedAtTotalSecs, pUpdatedEpochMs,
			pCases, pDeaths, pRecovered, pActive, pCritical, pFromCache, pCacheAgeSeconds, pUnavailable, pNote)
		If tRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao inserir Snapshot: "_tRS.%Message)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

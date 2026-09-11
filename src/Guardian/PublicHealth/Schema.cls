/// Setup do esquema de dados do bonus API publica (+2). Mesmo padrao de
/// Guardian.Monitor.Schema / Guardian.RAG.Schema / Guardian.Investigator.Schema:
/// DDL direto, nao Property de classe persistente.
Class Guardian.PublicHealth.Schema Extends %RegisteredObject
{

/// Cria a tabela de historico de snapshots se ainda nao existir. Idempotente.
ClassMethod Setup() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare(
			"CREATE TABLE IF NOT EXISTS Guardian_PublicHealth.Snapshot (" _
			"Source VARCHAR(100), " _
			"FetchedAt VARCHAR(30), " _
			"FetchedAtTotalSecs BIGINT, " _
			"UpdatedEpochMs VARCHAR(30), " _
			"CasesTotal BIGINT, " _
			"DeathsTotal BIGINT, " _
			"RecoveredTotal BIGINT, " _
			"ActiveTotal BIGINT, " _
			"CriticalTotal BIGINT, " _
			"FromCache INT, " _
			"CacheAgeSeconds INT, " _
			"Unavailable INT, " _
			"Note VARCHAR(300))")
		Set tRS = tStmt.%Execute()
		If tRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao criar Snapshot: "_tRS.%Message)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Remove a tabela (uso apenas em desenvolvimento/reset).
ClassMethod DropAll() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare("DROP TABLE IF EXISTS Guardian_PublicHealth.Snapshot")
		Do tStmt.%Execute()
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

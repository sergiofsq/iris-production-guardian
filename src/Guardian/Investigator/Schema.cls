/// Setup do esquema de dados do AI Incident Investigator (Fase 4). Mesma
/// abordagem de Guardian.RAG.Schema: DDL direto, nao Property de classe
/// persistente - consistente com o padrao ja validado no projeto.
Class Guardian.Investigator.Schema Extends %RegisteredObject
{

/// Cria a tabela de investigacoes se ainda nao existir. Idempotente.
ClassMethod Setup() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare(
			"CREATE TABLE IF NOT EXISTS Guardian_Investigator.Investigation (" _
			"Component VARCHAR(200), " _
			"WindowMinutes INT, " _
			"CreatedAt TIMESTAMP, " _
			"EventCount INT, " _
			"DocumentCount INT, " _
			"ModelAvailable INT, " _
			"Analysis VARCHAR(8000))")
		Set tRS = tStmt.%Execute()
		If tRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao criar Investigation: "_tRS.%Message)
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
		Do tStmt.%Prepare("DROP TABLE IF EXISTS Guardian_Investigator.Investigation")
		Do tStmt.%Execute()
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

/// Setup do esquema de dados da série temporal do Monitor (Fase 2,
/// reforço de 10/09/2026). Mesmo padrão de Guardian.RAG.Schema /
/// Guardian.Investigator.Schema: DDL direto, nao Property de classe
/// persistente.
Class Guardian.Monitor.Schema Extends %RegisteredObject
{

/// Cria a tabela de amostras de saude se ainda nao existir. Idempotente.
ClassMethod Setup() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare(
			"CREATE TABLE IF NOT EXISTS Guardian_Monitor.HealthSample (" _
			"Component VARCHAR(200), " _
			"Health VARCHAR(20), " _
			"QueueCount INT, " _
			"MessageCount INT, " _
			"RecentErrorCount INT, " _
			"CollectedAt TIMESTAMP)")
		Set tRS = tStmt.%Execute()
		If tRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao criar HealthSample: "_tRS.%Message)
		}

		// Indice por componente+tempo - a consulta de tendencia (ultimas N
		// amostras de um host) e a mais frequente, filtra por Component e
		// ordena por CollectedAt.
		Set tStmt2 = ##class(%SQL.Statement).%New()
		Set tSC2 = tStmt2.%Prepare(
			"CREATE INDEX idxHealthSampleComponent ON TABLE Guardian_Monitor.HealthSample (Component, CollectedAt)")
		If tSC2 = 1 {
			Set tRS2 = tStmt2.%Execute()
			If (tRS2.%SQLCODE < 0) && (tRS2.%SQLCODE '= -201) && (tRS2.%SQLCODE '= -324) {
				Throw ##class(%Exception.General).%New("Falha ao criar idxHealthSampleComponent: "_tRS2.%Message)
			}
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
		Do tStmt.%Prepare("DROP TABLE IF EXISTS Guardian_Monitor.HealthSample")
		Do tStmt.%Execute()
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

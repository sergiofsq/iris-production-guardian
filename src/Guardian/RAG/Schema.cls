/// Setup do esquema de dados do RAG Assistant (Fase 3). Tabelas criadas
/// via DDL direto (mesma abordagem validada no VR-001/02 - CREATE TABLE
/// com coluna VECTOR funciona na Community Edition sem licenca extra),
/// nao via Property de classe persistente, para evitar sintaxe de tipo
/// nao verificada.
Class Guardian.RAG.Schema Extends %RegisteredObject
{

/// Dimensao dos embeddings - ver justificativa em
/// 04_FASE_3_RAG_ASSISTANT.md secao 3.
Parameter EmbeddingDimension = 768;

/// Cria as tabelas do RAG se ainda nao existirem. Idempotente.
ClassMethod Setup() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare(
			"CREATE TABLE IF NOT EXISTS Guardian_RAG.Document (" _
			"Source VARCHAR(500), " _
			"Title VARCHAR(200), " _
			"Version VARCHAR(50), " _
			"CollectedAt TIMESTAMP)")
		Set tRS = tStmt.%Execute()
		If tRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao criar Document: "_tRS.%Message)
		}

		Set tStmt2 = ##class(%SQL.Statement).%New()
		Do tStmt2.%Prepare(
			"CREATE TABLE IF NOT EXISTS Guardian_RAG.Chunk (" _
			"DocumentId INT, " _
			"ChunkIndex INT, " _
			"ChunkText VARCHAR(4000), " _
			"Embedding VECTOR(DOUBLE, "_..#EmbeddingDimension_"), " _
			"EmbeddingModel VARCHAR(50), " _
			"CreatedAt TIMESTAMP)")
		Set tRS2 = tStmt2.%Execute()
		If tRS2.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao criar Chunk: "_tRS2.%Message)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

/// Remove todas as tabelas do RAG (uso apenas em desenvolvimento/reset).
ClassMethod DropAll() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tStmt = ##class(%SQL.Statement).%New()
		Do tStmt.%Prepare("DROP TABLE IF EXISTS Guardian_RAG.Chunk")
		Do tStmt.%Execute()

		Set tStmt2 = ##class(%SQL.Statement).%New()
		Do tStmt2.%Prepare("DROP TABLE IF EXISTS Guardian_RAG.Document")
		Do tStmt2.%Execute()
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

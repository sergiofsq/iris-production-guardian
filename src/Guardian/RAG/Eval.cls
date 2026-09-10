/// Conjunto de avaliação e ferramentas de calibração/comparação do RAG
/// Assistant (reforço de 10/09/2026, ver
/// docs/planejamento/04_FASE_3_RAG_ASSISTANT.md secao 7). 10 perguntas
/// (7 relevantes, com o Document.ID esperado do corpus original de 5
/// documentos; 3 irrelevantes, devem abster) - contra os 2 pontos
/// usados na calibracao original de MinSimilarity. Nao inclui as
/// perguntas ja usadas como exemplo em conversas anteriores por
/// coincidencia; escritas para cobrir fatos concretos e verificaveis de
/// cada um dos 5 documentos do corpus original.
Class Guardian.RAG.Eval Extends %RegisteredObject
{

/// Retorna o conjunto de avaliacao: %DynamicArray de
/// {question, relevant, expectedDocumentId}. expectedDocumentId so se
/// aplica quando relevant=1 (Document.ID do corpus original, ver
/// docs/planejamento/04_FASE_3_RAG_ASSISTANT.md secao 7 para a tabela
/// Source->ID).
ClassMethod EvalSet() As %DynamicArray
{
	Set tJSON = "["_
		"{""question"":""Por que o Google Gemini foi escolhido como provedor de IA?"",""relevant"":1,""expectedDocumentId"":9},"_
		"{""question"":""Qual e a dimensao do embedding usada e por que?"",""relevant"":1,""expectedDocumentId"":9},"_
		"{""question"":""O que causa o erro numero 5005 no cenario de falha da Production?"",""relevant"":1,""expectedDocumentId"":7},"_
		"{""question"":""Por que o IntegratedML nao funciona nesta imagem Community Edition?"",""relevant"":1,""expectedDocumentId"":6},"_
		"{""question"":""Quais sao os estados de saude do Production Monitor?"",""relevant"":1,""expectedDocumentId"":8},"_
		"{""question"":""Como e a arquitetura Service Process Operation da Production?"",""relevant"":1,""expectedDocumentId"":7},"_
		"{""question"":""O que e Foreign Table e funciona na Community Edition?"",""relevant"":1,""expectedDocumentId"":6},"_
		"{""question"":""Qual e a capital da Franca?"",""relevant"":0},"_
		"{""question"":""Como treinar um cachorro para sentar?"",""relevant"":0},"_
		"{""question"":""Receita de bolo de chocolate"",""relevant"":0}"_
		"]"
	Quit ##class(%DynamicArray).%FromJSON(tJSON)
}

/// Item 7: roda o conjunto de avaliacao contra o corpus de PRODUCAO
/// (Guardian_RAG.Chunk, o mesmo usado pelo RAG Assistant real) via
/// Guardian.RAG.Query.Retrieve, e reporta se o limiar MinSimilarity
/// (0.58) classifica cada pergunta corretamente (relevante deveria ficar
/// >= 0.58, irrelevante deveria ficar < 0.58). Amplia a calibracao
/// original (2 pontos observados) para o tamanho deste conjunto.
ClassMethod RunCalibration() As %DynamicObject
{
	Set tReport = {}
	Set tResults = []
	Set tCorrect = 0
	Set tTotal = 0

	Set tSet = ..EvalSet()
	Set tIter = tSet.%GetIterator()
	While tIter.%GetNext(.tKey, .tCase) {
		Set tTotal = tTotal + 1
		Set tRet = ##class(Guardian.RAG.Query).Retrieve(tCase.question)
		Set tPassed = $Select(tCase.relevant:
			(tRet.bestSimilarity >= 0.58),
			1: (tRet.bestSimilarity < 0.58))
		If tPassed {
			Set tCorrect = tCorrect + 1
		}

		Set tR = {}
		Set tR.question = tCase.question
		Set tR.relevant = tCase.relevant
		Set tR.bestSimilarity = tRet.bestSimilarity
		Set tR.thresholdCorrect = tPassed
		Do tResults.%Push(tR)
	}

	Set tReport.results = tResults
	Set tReport.correct = tCorrect
	Set tReport.total = tTotal
	Quit tReport
}

/// Item 6: para cada pergunta RELEVANTE do conjunto de avaliacao, roda
/// recuperacao vetorial pura (TOP 1 por VECTOR_COSINE) contra as duas
/// tabelas de comparacao de chunking (ChunkParagraphCompare = estrategia
/// em producao, ChunkAltStrategy = janela fixa ingenua) e reporta, para
/// cada estrategia: similaridade do melhor resultado e se o
/// Document.ID do melhor resultado bate com o esperado.
ClassMethod RunChunkingComparison() As %DynamicObject
{
	Set tReport = {}
	Set tResults = []
	Set tParaHits = 0, tFixedHits = 0, tParaSimSum = 0, tFixedSimSum = 0, tN = 0

	Set tSet = ..EvalSet()
	Set tIter = tSet.%GetIterator()
	While tIter.%GetNext(.tKey, .tCase) {
		Continue:'tCase.relevant

		Set tN = tN + 1
		Set tQueryVec = ##class(Guardian.RAG.GeminiClient).Embed(tCase.question)
		Set tQueryStr = ##class(Guardian.RAG.Ingestion).VectorToString(tQueryVec)

		Set tParaTop = ..Top1(tQueryStr, "ChunkParagraphCompare")
		Set tFixedTop = ..Top1(tQueryStr, "ChunkAltStrategy")

		Set tParaCorrect = (tParaTop.documentId = tCase.expectedDocumentId)
		Set tFixedCorrect = (tFixedTop.documentId = tCase.expectedDocumentId)
		If tParaCorrect { Set tParaHits = tParaHits + 1 }
		If tFixedCorrect { Set tFixedHits = tFixedHits + 1 }
		Set tParaSimSum = tParaSimSum + tParaTop.similarity
		Set tFixedSimSum = tFixedSimSum + tFixedTop.similarity

		Set tR = {}
		Set tR.question = tCase.question
		Set tR.expectedDocumentId = tCase.expectedDocumentId
		Set tR.paragraphDocumentId = tParaTop.documentId
		Set tR.paragraphSimilarity = tParaTop.similarity
		Set tR.paragraphCorrect = tParaCorrect
		Set tR.fixedWindowDocumentId = tFixedTop.documentId
		Set tR.fixedWindowSimilarity = tFixedTop.similarity
		Set tR.fixedWindowCorrect = tFixedCorrect
		Do tResults.%Push(tR)
	}

	Set tReport.results = tResults
	Set tReport.questionCount = tN
	Set tReport.paragraphTop1Accuracy = tParaHits / tN
	Set tReport.fixedWindowTop1Accuracy = tFixedHits / tN
	Set tReport.paragraphAvgSimilarity = tParaSimSum / tN
	Set tReport.fixedWindowAvgSimilarity = tFixedSimSum / tN
	Quit tReport
}

/// Melhor resultado (TOP 1 por VECTOR_COSINE) de pTableName
/// (ChunkParagraphCompare ou ChunkAltStrategy) para o vetor pQueryStr ja
/// convertido (ver Ingestion.VectorToString). Retorna
/// {documentId, similarity}.
ClassMethod Top1(pQueryStr As %String, pTableName As %String) As %DynamicObject
{
	Set tStmt = ##class(%SQL.Statement).%New()
	Do tStmt.%Prepare(
		"SELECT TOP 1 DocumentId, VECTOR_COSINE(Embedding, TO_VECTOR(?,DOUBLE)) AS Sim " _
		"FROM Guardian_RAG."_pTableName_" ORDER BY Sim DESC")
	Set tRS = tStmt.%Execute(pQueryStr)
	Set tResult = {}
	If tRS.%Next() {
		Set tResult.documentId = tRS.%Get("DocumentId")
		Set tResult.similarity = tRS.%Get("Sim")
	} Else {
		Set tResult.documentId = 0
		Set tResult.similarity = 0
	}
	Quit tResult
}

}

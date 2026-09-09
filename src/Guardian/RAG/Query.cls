/// Consulta do RAG Assistant (Fase 3): recuperacao vetorial +
/// geracao com citacao + abstencao. Nenhuma logica de negocio no
/// navegador - tudo aqui.
Class Guardian.RAG.Query Extends %RegisteredObject
{

/// Quantos fragmentos recuperar no maximo.
Parameter TopK = 5;

/// Limiar minimo de similaridade de cosseno para considerar um
/// fragmento relevante o suficiente para responder. Ajustado de 0.5 para
/// 0.58 apos observar 2 pontos reais: pergunta relevante ("por que o
/// IntegratedML nao funciona") = 0.653; pergunta irrelevante ("receita de
/// bolo de chocolate") = 0.518 (ficaria acima de 0.5, passando pelo
/// filtro). Ainda uma heuristica com poucos pontos, nao um limiar
/// validado estatisticamente - ver 04_FASE_3_RAG_ASSISTANT.md secao 5
/// para o plano de calibracao com um conjunto de avaliacao maior.
Parameter MinSimilarity = 0.58;

/// Faz a pergunta pQuestion contra o corpus indexado. Retorna um
/// %DynamicObject: {question, abstained, answer, sources:[...]}.
ClassMethod Ask(pQuestion As %String) As %DynamicObject
{
	Set tResult = {}
	Set tResult.question = pQuestion

	Set tQueryVec = ##class(Guardian.RAG.GeminiClient).Embed(pQuestion)
	Set tQueryStr = ##class(Guardian.RAG.Ingestion).VectorToString(tQueryVec)

	Set tStmt = ##class(%SQL.Statement).%New()
	Do tStmt.%Prepare(
		"SELECT TOP "_..#TopK_" c.ChunkText, c.DocumentId, d.Source, d.Title, " _
		"VECTOR_COSINE(c.Embedding, TO_VECTOR(?,DOUBLE)) AS Sim " _
		"FROM Guardian_RAG.Chunk AS c JOIN Guardian_RAG.Document AS d ON c.DocumentId = d.ID " _
		"ORDER BY Sim DESC")
	Set tRS = tStmt.%Execute(tQueryStr)

	Set tSources = []
	Set tBestSim = 0
	Set tContextText = ""
	While tRS.%Next() {
		Set tSim = tRS.%Get("Sim")
		Set tBestSim = $Select(tSim > tBestSim:tSim, 1:tBestSim)

		Set tSrc = {}
		Set tSrc.source = tRS.%Get("Source")
		Set tSrc.title = tRS.%Get("Title")
		Set tSrc.chunkText = tRS.%Get("ChunkText")
		Set tSrc.similarity = tSim
		Do tSources.%Push(tSrc)

		Set tContextText = tContextText _ "[Fonte: " _ tRS.%Get("Title") _ " (" _ tRS.%Get("Source") _ ")]" _ $Char(10) _ tRS.%Get("ChunkText") _ $Char(10, 10)
	}

	Set tResult.sources = tSources
	Set tResult.bestSimilarity = tBestSim

	If (tBestSim < ..#MinSimilarity) || (tSources.%Size() = 0) {
		Set tResult.abstained = 1
		Set tResult.answer = "Não há informação suficiente na base indexada para responder com confiança a esta pergunta."
		Quit tResult
	}

	Set tPrompt =
		"Responda a pergunta usando APENAS as informações fornecidas abaixo. " _
		"Se as informações não forem suficientes, diga explicitamente que não sabe - não invente. " _
		"Cite a fonte (o texto entre colchetes [Fonte: ...]) usada em cada afirmação." _
		$Char(10, 10) _
		"CONTEXTO:" _ $Char(10) _ tContextText _
		$Char(10) _
		"PERGUNTA: " _ pQuestion

	Set tResult.abstained = 0
	Set tResult.answer = ##class(Guardian.RAG.GeminiClient).Generate(tPrompt)

	Quit tResult
}

}

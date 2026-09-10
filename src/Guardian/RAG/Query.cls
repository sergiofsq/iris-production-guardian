/// Consulta do RAG Assistant (Fase 3): recuperacao hibrida (vetorial +
/// lexical via iFind, fundidas por Reciprocal Rank Fusion) + geracao com
/// citacao + abstencao. Nenhuma logica de negocio no navegador - tudo
/// aqui. Busca hibrida adicionada em 10/09/2026 - ver
/// docs/planejamento/04_FASE_3_RAG_ASSISTANT.md secao 6.
Class Guardian.RAG.Query Extends %RegisteredObject
{

/// Quantos fragmentos aparecem na resposta final (apos fundir vetorial + lexical).
Parameter TopK = 5;

/// Tamanho do conjunto candidato de cada busca (vetorial e lexical) antes
/// da fusao - maior que TopK para dar chance de um match lexical forte
/// mas com similaridade vetorial mediana entrar no resultado final.
Parameter CandidatePoolSize = 15;

/// Constante padrao de Reciprocal Rank Fusion (RRF): score = 1/(k+rank).
/// k=60 e o valor de referencia da literatura de IR, sem tuning especifico
/// para este corpus pequeno - suficiente para o objetivo de demonstracao.
Parameter RRFConstant = 60;

/// Limiar minimo de similaridade de cosseno (puramente vetorial - a busca
/// lexical NAO participa desta decisao) para considerar que ha informacao
/// suficiente para responder. Ajustado de 0.5 para 0.58 apos observar 2
/// pontos reais: pergunta relevante ("por que o IntegratedML nao
/// funciona") = 0.653; pergunta irrelevante ("receita de bolo de
/// chocolate") = 0.518 (ficaria acima de 0.5, passando pelo filtro).
/// Ainda uma heuristica com poucos pontos, nao um limiar validado
/// estatisticamente - ver docs/planejamento/04_FASE_3_RAG_ASSISTANT.md
/// secao 5 para o plano de calibracao com um conjunto de avaliacao maior.
/// Mantido como o unico sinal de abstencao (mesmo apos a fusao hibrida)
/// para nao invalidar essa calibracao ja testada.
Parameter MinSimilarity = 0.58;

/// Recuperacao hibrida pura (sem geracao) - reaproveitada por Ask() e
/// por qualquer outra parte do projeto que precise so dos trechos
/// relevantes (ex.: Guardian.Investigator.EvidenceCollector, Fase 4).
/// Retorna um %DynamicObject: {sources:[...], bestSimilarity, contextText}.
ClassMethod Retrieve(pQuestion As %String) As %DynamicObject
{
	Set tResult = {}

	Set tQueryVec = ##class(Guardian.RAG.GeminiClient).Embed(pQuestion)
	Set tQueryStr = ##class(Guardian.RAG.Ingestion).VectorToString(tQueryVec)

	// Busca vetorial (semantica) - a mesma consulta ja testada da v1,
	// so que trazendo um pool maior de candidatos para a fusao.
	Set tVecStmt = ##class(%SQL.Statement).%New()
	Do tVecStmt.%Prepare(
		"SELECT TOP "_..#CandidatePoolSize_" c.ID, " _
		"VECTOR_COSINE(c.Embedding, TO_VECTOR(?,DOUBLE)) AS Sim " _
		"FROM Guardian_RAG.Chunk AS c ORDER BY Sim DESC")
	Set tVecRS = tVecStmt.%Execute(tQueryStr)

	Set tRank = 0
	Set tBestSim = 0
	Set tScore = 0
	Kill tRRF, tSim
	While tVecRS.%Next() {
		Set tRank = tRank + 1
		Set tId = tVecRS.%Get("ID")
		Set tSimVal = tVecRS.%Get("Sim")
		Set tSim(tId) = tSimVal
		Set tRRF(tId) = $Get(tRRF(tId), 0) + (1 / (..#RRFConstant + tRank))
		If tRank = 1 {
			Set tBestSim = tSimVal
		}
	}

	// Busca lexical (iFind) - sinal booleano de presenca, nao um rank
	// verdadeiro: a API de ranking do iFind (%iFind.Rank) nao aceitou a
	// sintaxe esperada nos testes ao vivo de 10/09/2026, entao um match
	// lexical soma um bonus fixo (equivalente ao rank 1) em vez de uma
	// posicao inventada - mais honesto que fingir uma ordenacao que nao
	// foi de fato calculada pelo motor de texto.
	Set tLexStmt = ##class(%SQL.Statement).%New()
	Set tLexSC = tLexStmt.%Prepare(
		"SELECT TOP "_..#CandidatePoolSize_" c.ID " _
		"FROM Guardian_RAG.Chunk AS c WHERE c.%ID %FIND search_index(idxChunkTextFind, ?)")
	If tLexSC = 1 {
		Set tLexRS = tLexStmt.%Execute(pQuestion)
		While tLexRS.%Next() {
			Set tId = tLexRS.%Get("ID")
			Set tRRF(tId) = $Get(tRRF(tId), 0) + (1 / (..#RRFConstant + 1))
		}
	}

	// Ordena os candidatos fundidos por score RRF desc e monta o TopK final.
	// Selecao por maximo repetido (nao $Order, que percorre por CHAVE - o
	// ID do chunk - e nao pelo valor do score; poucos candidatos aqui,
	// no maximo 2x CandidatePoolSize, entao O(TopK*N) e desprezivel).
	Set tSources = []
	Set tContextText = ""
	Set tCount = 0
	Kill tUsed
	For tI = 1:1:..#TopK {
		Set tBestId = "", tBestScore = -1, tId = ""
		For {
			Set tId = $Order(tRRF(tId))
			Quit:tId=""
			If (tRRF(tId) > tBestScore) && '$Data(tUsed(tId)) {
				Set tBestScore = tRRF(tId)
				Set tBestId = tId
			}
		}
		Quit:tBestId=""
		Set tUsed(tBestId) = 1
		Set tId = tBestId

		// Similaridade para exibicao: reaproveita a do pool vetorial se o
		// candidato veio de la; se veio so da busca lexical, calcula sob
		// demanda para manter a fonte transparente (mesmo padrao das
		// demais - nunca mostrar um numero que nao foi realmente calculado).
		If $Data(tSim(tId)) {
			Set tSimShow = tSim(tId)
		} Else {
			Set tSimStmt = ##class(%SQL.Statement).%New()
			Do tSimStmt.%Prepare("SELECT VECTOR_COSINE(Embedding, TO_VECTOR(?,DOUBLE)) AS Sim FROM Guardian_RAG.Chunk WHERE ID = ?")
			Set tSimRS = tSimStmt.%Execute(tQueryStr, tId)
			Do tSimRS.%Next()
			Set tSimShow = tSimRS.%Get("Sim")
		}

		Set tRowStmt = ##class(%SQL.Statement).%New()
		Do tRowStmt.%Prepare(
			"SELECT c.ChunkText, d.Source, d.Title " _
			"FROM Guardian_RAG.Chunk AS c JOIN Guardian_RAG.Document AS d ON c.DocumentId = d.ID " _
			"WHERE c.ID = ?")
		Set tRowRS = tRowStmt.%Execute(tId)
		Do tRowRS.%Next()

		Set tSrc = {}
		Set tSrc.source = tRowRS.%Get("Source")
		Set tSrc.title = tRowRS.%Get("Title")
		Set tSrc.chunkText = tRowRS.%Get("ChunkText")
		Set tSrc.similarity = tSimShow
		Do tSources.%Push(tSrc)

		Set tContextText = tContextText _ "[Fonte: " _ tRowRS.%Get("Title") _ " (" _ tRowRS.%Get("Source") _ ")]" _ $Char(10) _ tRowRS.%Get("ChunkText") _ $Char(10, 10)
		Set tCount = tCount + 1
	}

	Set tResult.sources = tSources
	Set tResult.bestSimilarity = tBestSim
	Set tResult.contextText = tContextText

	Quit tResult
}

/// Faz a pergunta pQuestion contra o corpus indexado. Retorna um
/// %DynamicObject: {question, abstained, answer, sources:[...]}.
ClassMethod Ask(pQuestion As %String) As %DynamicObject
{
	Set tResult = {}
	Set tResult.question = pQuestion

	Set tRetrieval = ..Retrieve(pQuestion)
	Set tResult.sources = tRetrieval.sources
	Set tResult.bestSimilarity = tRetrieval.bestSimilarity

	If (tRetrieval.bestSimilarity < ..#MinSimilarity) || (tRetrieval.sources.%Size() = 0) {
		Set tResult.abstained = 1
		Set tResult.answer = "Não há informação suficiente na base indexada para responder com confiança a esta pergunta."
		Quit tResult
	}

	Set tPrompt =
		"Responda a pergunta usando APENAS as informações fornecidas abaixo. " _
		"Se as informações não forem suficientes, diga explicitamente que não sabe - não invente. " _
		"Cite a fonte (o texto entre colchetes [Fonte: ...]) usada em cada afirmação." _
		$Char(10, 10) _
		"CONTEXTO:" _ $Char(10) _ tRetrieval.contextText _
		$Char(10) _
		"PERGUNTA: " _ pQuestion

	Set tResult.abstained = 0
	Set tResult.answer = ##class(Guardian.RAG.GeminiClient).Generate(tPrompt)

	Quit tResult
}

}

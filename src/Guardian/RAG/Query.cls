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
///
/// pInvestigationContext (opcional): analise completa (RESUMO / OBSERVACOES
/// / HIPOTESES / LACUNAS / PROXIMOS PASSOS SUGERIDOS) da ultima investigacao
/// do AI Incident Investigator, quando o usuario pergunta "como resolver o
/// problema investigado em X" a partir do RAG Assistant (ver
/// Guardian.UI.RAGPage). Antes desta mudanca essa investigacao so aparecia
/// como um resumo visual na pagina - nunca era enviada ao modelo, entao o
/// RAG so tinha os documentos indexados (que raramente cobrem o incidente
/// especifico) para responder e abstinha mesmo tendo a analise completa (com
/// PROXIMOS PASSOS SUGERIDOS) disponivel a poucos centimetros na tela.
/// Quando presente, este contexto participa da geracao e TAMBEM evita a
/// abstencao por baixa similaridade nos documentos (MinSimilarity continua
/// controlando exclusivamente o corpus de documentos - ver comentario do
/// parametro - a investigacao e uma fonte de grounding independente, coletada
/// como evidencia real por Guardian.Investigator.EvidenceCollector).
/// pLang ("pt" ou "en", default "pt"): idioma da resposta gerada e da
/// mensagem de abstencao - preferencia do visitante (Guardian.UI.I18n),
/// repassada aqui em vez de importada diretamente para o pacote RAG nao
/// depender do pacote UI. Os documentos recuperados continuam no idioma em
/// que foram indexados (pt ou en, corpus misto) - o prompt pede
/// explicitamente para a RESPOSTA (nao a citacao literal) sair no idioma
/// pedido mesmo assim.
/// pGenerationClient (13/09/2026, bonus multimodelo): nome da classe usada
/// para a etapa de GERACAO (default Guardian.RAG.GeminiClient). A
/// RECUPERACAO acima (Retrieve, chamada logo abaixo) sempre usa
/// Guardian.RAG.GeminiClient.Embed - o corpus ja foi indexado com vetores
/// Gemini de 768 dimensoes, entao trocar so a embedding aqui exigiria
/// reingestar tudo num espaco vetorial novo sem necessidade. Trocar o
/// provedor de fato so importa na geracao (Guardian.UI.RAGAltPage passa
/// "Guardian.RAG.GroqClient" aqui) - a classe informada so precisa
/// implementar Generate(pPrompt) com a mesma assinatura de
/// Guardian.RAG.GeminiClient.Generate.
ClassMethod Ask(pQuestion As %String, pInvestigationContext As %String = "", pLang As %String = "pt", pGenerationClient As %String = "Guardian.RAG.GeminiClient") As %DynamicObject
{
	Set tResult = {}
	Set tResult.question = pQuestion
	Set tEn = (pLang = "en")

	Set tRetrieval = ..Retrieve(pQuestion)
	Set tResult.sources = tRetrieval.sources
	Set tResult.bestSimilarity = tRetrieval.bestSimilarity

	Set tHasDocs = (tRetrieval.bestSimilarity >= ..#MinSimilarity) && (tRetrieval.sources.%Size() > 0)
	Set tHasInvestigation = (pInvestigationContext '= "")

	If 'tHasDocs && 'tHasInvestigation {
		Set tResult.abstained = 1
		Set tResult.answer = $Select(tEn:
			"There isn't enough information in the indexed corpus to answer this question with confidence.", 1:
			"Não há informação suficiente na base indexada para responder com confiança a esta pergunta.")
		Quit tResult
	}

	If tEn {
		Set tPrompt =
			"You are the incident-resolution assistant for IRIS Production Guardian. " _
			"Answer the question using ONLY the information provided below (the current incident investigation and/or the indexed documentation). " _
			"If neither is sufficient, explicitly say you don't know - do not invent. " _
			"Give a practical, actionable answer: list the steps in order, and whenever the documentation names a Management Portal menu path, screen, button or command, quote that path/command literally (e.g. 'Interoperability -> Configure -> Production', 'Message Viewer -> select the message -> Resend'). " _
			"Answer in English regardless of the language of the source material below. " _
			"Cite the source of each statement: 'the current investigation' for data from the AI Incident Investigator, or the text in brackets [Source: ...] for documents." _
			$Char(10, 10)
	} Else {
		Set tPrompt =
			"Você é o assistente de resolução de incidentes do IRIS Production Guardian. " _
			"Responda a pergunta usando APENAS as informações fornecidas abaixo (a investigação de incidente atual e/ou a documentação indexada). " _
			"Se nenhuma das duas for suficiente, diga explicitamente que não sabe - não invente. " _
			"Dê uma resposta prática e acionável: liste os passos em ordem, e sempre que a documentação indicar um caminho de menu do Management Portal, uma tela, um botão ou um comando, cite esse caminho/comando literalmente (ex.: 'Interoperability -> Configure -> Production', 'Message Viewer -> selecionar a mensagem -> Resend'). " _
			"Responda em português, mesmo que o material-fonte abaixo esteja em outro idioma. " _
			"Cite a fonte de cada afirmação: 'a investigação atual' para dados vindos do AI Incident Investigator, ou o texto entre colchetes [Fonte: ...] para documentos." _
			$Char(10, 10)
	}

	If tHasInvestigation {
		Set tPrompt = tPrompt _ $Select(tEn:"CURRENT INVESTIGATION (AI Incident Investigator - real evidence and analysis already generated for this incident):", 1:"INVESTIGAÇÃO ATUAL (AI Incident Investigator - evidência real coletada e análise já geradas para este incidente):") _ $Char(10) _ pInvestigationContext _ $Char(10, 10)
	}

	If tHasDocs {
		Set tPrompt = tPrompt _ $Select(tEn:"INDEXED DOCUMENTATION:", 1:"DOCUMENTAÇÃO INDEXADA:") _ $Char(10) _ tRetrieval.contextText _ $Char(10)
	}

	Set tPrompt = tPrompt _ $Char(10) _ $Select(tEn:"QUESTION: ", 1:"PERGUNTA: ") _ pQuestion

	Set tResult.abstained = 0
	Set tResult.answer = $ClassMethod(pGenerationClient, "Generate", tPrompt)

	Quit tResult
}

}

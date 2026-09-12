/// Ingestao de documentos no RAG Assistant (Fase 3): chunking + embedding
/// (Guardian.RAG.GeminiClient) + armazenamento (Guardian_RAG.Document /
/// Guardian_RAG.Chunk). Estrategia de chunking documentada em
/// docs/planejamento/04_FASE_3_RAG_ASSISTANT.md secao 3.2.
Class Guardian.RAG.Ingestion Extends %RegisteredObject
{

/// Tamanho alvo de cada fragmento, em caracteres.
Parameter ChunkSize = 800;

/// Sobreposicao entre fragmentos consecutivos, em caracteres.
Parameter ChunkOverlap = 150;

/// Converte um %DynamicArray de doubles (retorno de GeminiClient.Embed)
/// em string separada por virgula, formato aceito por TO_VECTOR.
ClassMethod VectorToString(pVector As %DynamicArray) As %String
{
	Set tStr = ""
	Set tIter = pVector.%GetIterator()
	Set tFirst = 1
	While tIter.%GetNext(.tKey, .tVal) {
		If 'tFirst {
			Set tStr = tStr _ ","
		}
		Set tStr = tStr _ tVal
		Set tFirst = 0
	}
	Quit tStr
}

/// Divide pText em fragmentos por paragrafo, agrupando paragrafos ate
/// ChunkSize e quebrando paragrafos muito longos com sobreposicao de
/// ChunkOverlap caracteres. Retorna %DynamicArray de strings.
ClassMethod SplitIntoChunks(pText As %String) As %DynamicArray
{
	Set tChunks = []
	Set tSep = $Char(10)_$Char(10)
	Set tLen = $Length(pText)
	Set tParaCount = 0
	Set tStart = 1
	Set tIdx = $Find(pText, tSep, tStart)
	While tIdx '= 0 {
		Set tPara = $Extract(pText, tStart, tIdx - $Length(tSep) - 1)
		Set tParaCount = tParaCount + 1
		Set tParaList(tParaCount) = tPara
		Set tStart = tIdx
		Set tIdx = $Find(pText, tSep, tStart)
	}
	If tStart <= tLen {
		Set tParaCount = tParaCount + 1
		Set tParaList(tParaCount) = $Extract(pText, tStart, tLen)
	}

	Set tCurrent = ""
	For tI = 1:1:tParaCount {
		Set tPara = $ZStrip(tParaList(tI), "<>W")
		Continue:tPara=""

		If $Length(tPara) > ..#ChunkSize {
			// Paragrafo maior que o tamanho alvo: fecha o chunk atual e
			// quebra o paragrafo em janelas deslizantes com sobreposicao.
			If tCurrent '= "" {
				Do tChunks.%Push(tCurrent)
				Set tCurrent = ""
			}
			Set tWinStart = 1
			While tWinStart <= $Length(tPara) {
				Set tWinEnd = $Select((tWinStart + ..#ChunkSize - 1) < $Length(tPara): tWinStart + ..#ChunkSize - 1, 1: $Length(tPara))
				Do tChunks.%Push($Extract(tPara, tWinStart, tWinEnd))
				Quit:tWinEnd=$Length(tPara)
				Set tWinStart = tWinEnd - ..#ChunkOverlap + 1
			}
		} ElseIf ($Length(tCurrent) + $Length(tPara) + 2) > ..#ChunkSize {
			Do tChunks.%Push(tCurrent)
			Set tCurrent = tPara
		} Else {
			Set tCurrent = $Select(tCurrent="":tPara, 1:tCurrent_$Char(10,10)_tPara)
		}
	}
	If tCurrent '= "" {
		Do tChunks.%Push(tCurrent)
	}

	Quit tChunks
}

/// Estrategia alternativa de chunking, para a comparacao formal da
/// secao 7 de docs/planejamento/04_FASE_3_RAG_ASSISTANT.md: janela fixa
/// de ChunkSize caracteres com ChunkOverlap de sobreposicao, ignorando
/// limites de paragrafo (ao contrario de SplitIntoChunks). Corta no meio
/// de frases/paragrafos de proposito - e a hipotese "ingenua" contra a
/// qual a estrategia em producao (paragrafo-aware) e comparada.
ClassMethod SplitFixedWindow(pText As %String) As %DynamicArray
{
	Set tChunks = []
	Set tLen = $Length(pText)
	Set tWinStart = 1
	While tWinStart <= tLen {
		Set tWinEnd = $Select((tWinStart + ..#ChunkSize - 1) < tLen: tWinStart + ..#ChunkSize - 1, 1: tLen)
		Set tChunkText = $ZStrip($Extract(pText, tWinStart, tWinEnd), "<>W")
		If tChunkText '= "" {
			Do tChunks.%Push(tChunkText)
		}
		Quit:tWinEnd=tLen
		Set tWinStart = tWinEnd - ..#ChunkOverlap + 1
	}
	Quit tChunks
}

/// Grava pChunks (ja fragmentado) numa das tabelas de comparacao de
/// chunking (ChunkParagraphCompare ou ChunkAltStrategy), referenciando um
/// Document.ID que ja existe - compartilhado pelas duas estrategias para
/// nao duplicar o loop de embedding+insert.
ClassMethod IngestChunksToComparisonTable(pTableName As %String, pDocumentId As %Integer, pChunks As %DynamicArray) As %Integer
{
	Set tCount = 0
	Set tIter = pChunks.%GetIterator()
	While tIter.%GetNext(.tKey, .tChunkText) {
		Set tVec = ##class(Guardian.RAG.GeminiClient).Embed(tChunkText)
		Set tVecStr = ..VectorToString(tVec)

		Set tInsStmt = ##class(%SQL.Statement).%New()
		Do tInsStmt.%Prepare("INSERT INTO Guardian_RAG."_pTableName_" (DocumentId, ChunkIndex, ChunkText, Embedding, EmbeddingModel, CreatedAt) VALUES (?,?,?,TO_VECTOR(?,DOUBLE),?,?)")
		Set tInsRS = tInsStmt.%Execute(pDocumentId, tCount, tChunkText, tVecStr, "gemini-embedding-001", $ZDATETIME($Horolog, 3))
		If tInsRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao inserir "_pTableName_" "_tCount_": "_tInsRS.%Message)
		}
		Set tCount = tCount + 1
	}
	Quit tCount
}

/// Ingere um documento: cria a linha em Document, quebra pText em
/// fragmentos, gera embedding de cada um e grava em Chunk. Retorna o
/// numero de fragmentos gravados.
ClassMethod IngestDocument(pSource As %String, pTitle As %String, pVersion As %String, pText As %String) As %Integer
{
	Set tStmt = ##class(%SQL.Statement).%New()
	Do tStmt.%Prepare("INSERT INTO Guardian_RAG.Document (Source, Title, Version, CollectedAt) VALUES (?,?,?,?)")
	Set tRS = tStmt.%Execute(pSource, pTitle, pVersion, $ZDATETIME($Horolog, 3))
	If tRS.%SQLCODE < 0 {
		Throw ##class(%Exception.General).%New("Falha ao inserir Document: "_tRS.%Message)
	}

	// LAST_IDENTITY() via um %SQL.Statement separado nao funciona (testado
	// e confirmado vazio) - %ROWID no proprio resultset do INSERT e' o
	// jeito real que funciona.
	Set tDocId = tRS.%ROWID

	Set tChunks = ..SplitIntoChunks(pText)
	Set tCount = 0
	Set tIter = tChunks.%GetIterator()
	While tIter.%GetNext(.tKey, .tChunkText) {
		Set tVec = ##class(Guardian.RAG.GeminiClient).Embed(tChunkText)
		Set tVecStr = ..VectorToString(tVec)

		Set tInsStmt = ##class(%SQL.Statement).%New()
		Do tInsStmt.%Prepare("INSERT INTO Guardian_RAG.Chunk (DocumentId, ChunkIndex, ChunkText, Embedding, EmbeddingModel, CreatedAt) VALUES (?,?,?,TO_VECTOR(?,DOUBLE),?,?)")
		Set tInsRS = tInsStmt.%Execute(tDocId, tCount, tChunkText, tVecStr, "gemini-embedding-001", $ZDATETIME($Horolog, 3))
		If tInsRS.%SQLCODE < 0 {
			Throw ##class(%Exception.General).%New("Falha ao inserir Chunk "_tCount_": "_tInsRS.%Message)
		}
		Set tCount = tCount + 1
	}

	Quit tCount
}

/// Le pPath (arquivo texto no filesystem do container) e ingere via
/// IngestDocument. Util para ingerir a documentacao do proprio projeto
/// sem passar o conteudo inteiro por um terminal interativo.
ClassMethod IngestFile(pPath As %String, pSource As %String, pTitle As %String, pVersion As %String) As %Integer
{
	Set tFile = ##class(%Stream.FileCharacter).%New()
	// TranslateTable precisa ser setado ANTES do arquivo ser lido (Read
	// abre o arquivo fisico na primeira chamada) - sem isso o stream usa a
	// tabela padrao do processo, que nao decodifica UTF-8: cada caractere
	// acentuado (2+ bytes no arquivo, ja que os .md sao UTF-8) virava 2+
	// "caracteres" separados (string "estreita"/1 byte = 1 char) em vez de
	// 1 codepoint Unicode. O texto parecia certo num terminal (que so
	// repassa os bytes originais sem retraduzir), mas saia com o
	// acentuado dobrado ("Ã©") na pagina CSP (que recodifica de verdade
	// para UTF-8 na saida) - bug encontrado e corrigido em 12/09/2026, ver
	// Guardian.RAG.RepairEncodingOnce para o reparo dos dados ja
	// ingeridos antes desta correcao.
	Set tFile.TranslateTable = "UTF8"
	Set tSC = tFile.LinkToFile(pPath)
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}
	Set tText = tFile.Read(tFile.Size)
	Quit ..IngestDocument(pSource, pTitle, pVersion, tText)
}

/// Le pPath e ingere nas DUAS tabelas de comparacao (paragrafo e janela
/// fixa), a partir do MESMO texto atual - garante que a comparacao seja
/// justa (mesmo conteudo, so a estrategia de corte muda). Referencia um
/// Document.ID que ja existe, nao cria Document novo.
ClassMethod IngestFileForComparison(pPath As %String, pDocumentId As %Integer) As %String
{
	Set tFile = ##class(%Stream.FileCharacter).%New()
	// Ver comentario em IngestFile - mesma correcao de decodificacao UTF-8.
	Set tFile.TranslateTable = "UTF8"
	Set tSC = tFile.LinkToFile(pPath)
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}
	Set tText = tFile.Read(tFile.Size)

	Set tParaChunks = ..SplitIntoChunks(tText)
	Set tParaCount = ..IngestChunksToComparisonTable("ChunkParagraphCompare", pDocumentId, tParaChunks)

	Set tFixedChunks = ..SplitFixedWindow(tText)
	Set tFixedCount = ..IngestChunksToComparisonTable("ChunkAltStrategy", pDocumentId, tFixedChunks)

	Quit "paragraph="_tParaCount_" fixedWindow="_tFixedCount
}

}

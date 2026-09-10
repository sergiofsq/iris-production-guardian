/// Cliente COS para a API do Google Gemini (embeddings + geracao), via
/// %Net.HttpRequest - sem Python, conforme premissa do projeto (contexto,
/// secao 1.1: acesso a modelo de IA nao exige backend Python). Chave lida
/// de Ens.Config.Credentials ("Gemini") - nunca em codigo-fonte.
Class Guardian.RAG.GeminiClient Extends %RegisteredObject
{

Parameter Server = "generativelanguage.googleapis.com";

Parameter SslConfig = "PublicHTTPS";

Parameter EmbeddingModel = "gemini-embedding-001";

Parameter GenerationModel = "gemini-3.6-flash";

/// Le a chave de API armazenada em Ens.Config.Credentials.
ClassMethod GetApiKey() As %String
{
	Set tSC = ##class(Ens.Config.Credentials).GetCredentialsObj(.tCred, $classname(), "Ens.Config.Credentials", "Gemini")
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}
	Quit tCred.Password
}

/// Monta um %Net.HttpRequest configurado para a API do Gemini.
ClassMethod NewRequest() As %Net.HttpRequest
{
	Set tHttp = ##class(%Net.HttpRequest).%New()
	Set tHttp.Server = ..#Server
	Set tHttp.Https = 1
	Set tHttp.SSLConfiguration = ..#SslConfig
	Set tHttp.ContentType = "application/json"
	Quit tHttp
}

/// Retorna um %DynamicArray com os valores do embedding de pText.
/// pDimension: ver justificativa em docs/planejamento/04_FASE_3_RAG_ASSISTANT.md secao 3.
ClassMethod Embed(pText As %String, pDimension As %Integer = 768) As %DynamicArray
{
	Set tHttp = ..NewRequest()

	Set tBody = {}
	Set tContent = {}
	Set tParts = []
	Set tPart = {}
	Set tPart.text = pText
	Do tParts.%Push(tPart)
	Set tContent.parts = tParts
	Set tBody.content = tContent
	Set tBody.outputDimensionality = pDimension

	Do tHttp.EntityBody.Write(tBody.%ToJSON())

	Set tPath = "/v1beta/models/"_..#EmbeddingModel_":embedContent?key="_..GetApiKey()
	Set tSC = tHttp.Post(tPath)
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}

	Set tRespText = tHttp.HttpResponse.Data.Read(32000)
	Set tResp = {}.%FromJSON(tRespText)

	If tHttp.HttpResponse.StatusCode '= 200 {
		Set tErrObj = tResp.%Get("error")
		Set tMsg = $Select($IsObject(tErrObj):tErrObj.message, 1:tRespText)
		Throw ##class(%Exception.General).%New("Gemini embed HTTP "_tHttp.HttpResponse.StatusCode_": "_tMsg)
	}

	Quit tResp.embedding.values
}

/// Gera texto a partir de um prompt simples (sem contexto de sistema
/// separado nesta v1). Retorna o texto da primeira resposta.
ClassMethod Generate(pPrompt As %String) As %String
{
	Set tHttp = ..NewRequest()

	Set tBody = {}
	Set tContents = []
	Set tContent = {}
	Set tParts = []
	Set tPart = {}
	Set tPart.text = pPrompt
	Do tParts.%Push(tPart)
	Set tContent.parts = tParts
	Do tContents.%Push(tContent)
	Set tBody.contents = tContents

	Do tHttp.EntityBody.Write(tBody.%ToJSON())

	Set tPath = "/v1beta/models/"_..#GenerationModel_":generateContent?key="_..GetApiKey()
	Set tSC = tHttp.Post(tPath)
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}

	Set tRespText = tHttp.HttpResponse.Data.Read(32000)
	Set tResp = {}.%FromJSON(tRespText)

	If tHttp.HttpResponse.StatusCode '= 200 {
		Set tErrObj = tResp.%Get("error")
		Set tMsg = $Select($IsObject(tErrObj):tErrObj.message, 1:tRespText)
		Throw ##class(%Exception.General).%New("Gemini generate HTTP "_tHttp.HttpResponse.StatusCode_": "_tMsg)
	}

	Set tCandidate = tResp.candidates.%Get(0)
	Quit tCandidate.content.parts.%Get(0).text
}

}

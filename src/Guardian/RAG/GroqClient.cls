/// Cliente COS para a API do Groq (geracao apenas - Guardian.UI.RAGAltPage
/// reaproveita a recuperacao/embeddings ja indexados com
/// Guardian.RAG.GeminiClient, so a geracao troca de provedor, ver
/// Guardian.RAG.Query.Ask pGenerationClient), via %Net.HttpRequest - sem
/// Python, mesma premissa de Guardian.RAG.GeminiClient. Endpoint
/// compativel com o formato OpenAI Chat Completions. Chave lida de
/// Ens.Config.Credentials ("Groq") - nunca em codigo-fonte.
Class Guardian.RAG.GroqClient Extends %RegisteredObject
{

Parameter Server = "api.groq.com";

Parameter SslConfig = "PublicHTTPS";

Parameter GenerationModel = "openai/gpt-oss-120b";

/// Le a chave de API armazenada em Ens.Config.Credentials.
ClassMethod GetApiKey() As %String
{
	Set tSC = ##class(Ens.Config.Credentials).GetCredentialsObj(.tCred, $classname(), "Ens.Config.Credentials", "Groq")
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}
	Quit tCred.Password
}

/// Monta um %Net.HttpRequest configurado para a API do Groq.
ClassMethod NewRequest() As %Net.HttpRequest
{
	Set tHttp = ##class(%Net.HttpRequest).%New()
	Set tHttp.Server = ..#Server
	Set tHttp.Https = 1
	Set tHttp.SSLConfiguration = ..#SslConfig
	Set tHttp.ContentType = "application/json"
	Do tHttp.SetHeader("Authorization", "Bearer "_..GetApiKey())
	Quit tHttp
}

/// Gera texto a partir de um prompt simples. Mesma assinatura de
/// Guardian.RAG.GeminiClient.Generate(pPrompt) - contrato exigido por
/// Guardian.RAG.Query.Ask, que invoca o classname passado em
/// pGenerationClient via $ClassMethod.
ClassMethod Generate(pPrompt As %String) As %String
{
	Set tHttp = ..NewRequest()

	Set tBody = {}
	Set tMessages = []
	Set tMsg = {}
	Set tMsg.role = "user"
	Set tMsg.content = pPrompt
	Do tMessages.%Push(tMsg)
	Set tBody.model = ..#GenerationModel
	Set tBody.messages = tMessages

	Do tHttp.EntityBody.Write(tBody.%ToJSON())

	Set tPath = "/openai/v1/chat/completions"
	Set tSC = tHttp.Post(tPath)
	If $$$ISERR(tSC) {
		Throw ##class(%Exception.StatusException).CreateFromStatus(tSC)
	}

	Set tRespText = tHttp.HttpResponse.Data.Read(32000)
	Set tResp = {}.%FromJSON(tRespText)

	If tHttp.HttpResponse.StatusCode '= 200 {
		Set tErrObj = tResp.%Get("error")
		Set tErrMsg = $Select($IsObject(tErrObj):tErrObj.message, 1:tRespText)
		Throw ##class(%Exception.General).%New("Groq generate HTTP "_tHttp.HttpResponse.StatusCode_": "_tErrMsg)
	}

	Set tChoice = tResp.choices.%Get(0)
	Quit tChoice.message.content
}

}

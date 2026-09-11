/// Adapter de entrada customizado (bonus API publica, +2): substitui o
/// InboundAdapter de arquivo da Fase 1 por polling HTTP real a uma API
/// publica de saude (disease.sh, sem chave/autenticacao). A API nao
/// publica header de rate limit (confirmado em teste ao vivo em
/// 10/09/2026), entao o intervalo de polling e a nossa politica de uso
/// responsavel - imposta aqui mesmo, nao pelo framework: achado real
/// (10/09/2026) ao testar que o framework chama OnTask() continuamente
/// (a cada ciclo do host, nao a cada CallInterval), ficando a cargo do
/// proprio adapter checar o tempo decorrido e so agir quando devido -
/// mesmo padrao que EnsLib.File.InboundAdapter faz internamente. Toda
/// chamada real (nao os no-ops entre polls), com sucesso ou falha, gera
/// exatamente uma mensagem para o BusinessHost - a decisao de usar cache
/// ou marcar indisponivel fica na Operation (unico dono da tabela de
/// historico).
Class Guardian.Adapter.PublicHealthPollAdapter Extends Ens.InboundAdapter
{

Property HTTPServer As %String [ InitialExpression = "disease.sh" ];

Property HTTPPort As %Integer [ InitialExpression = 443 ];

Property Endpoint As %String [ InitialExpression = "/v3/covid-19/all" ];

Property SSLConfig As %String [ InitialExpression = "PublicHTTPS" ];

Property Timeout As %Integer [ InitialExpression = 10 ];

/// Ultimo poll real (nao no-op), em segundos "tipo horolog" (dias*86400 +
/// segundos do dia) - propriedade em memoria do job do adapter, nao
/// persistida (nao precisa sobreviver a um restart da Production).
Property LastPollTotalSecs As %Integer [ InitialExpression = 0 ];

Method OnTask() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tNowTotalSecs = ($Piece($Horolog, ",", 1) * 86400) + $Piece($Horolog, ",", 2)
		Set tElapsed = tNowTotalSecs - ..LastPollTotalSecs
		Quit:(tElapsed < ..CallInterval)
		Set ..LastPollTotalSecs = tNowTotalSecs

		Set tHttp = ##class(%Net.HttpRequest).%New()
		Set tHttp.Server = ..HTTPServer
		Set tHttp.Port = ..HTTPPort
		Set tHttp.Https = 1
		Set tHttp.SSLConfiguration = ..SSLConfig
		Set tHttp.Timeout = ..Timeout

		Set tPayload = {}
		Set tPayload.fetchFailed = 0
		Set tPayload.httpStatus = ""

		Try {
			Set tGetSC = tHttp.Get(..Endpoint)
			If $$$ISERR(tGetSC) {
				Set tPayload.fetchFailed = 1
				Set tPayload.httpStatus = "connect-error: "_$System.Status.GetErrorText(tGetSC)
			} ElseIf (tHttp.HttpResponse.StatusCode '= "200") {
				Set tPayload.fetchFailed = 1
				Set tPayload.httpStatus = tHttp.HttpResponse.StatusCode
			} Else {
				Set tPayload.httpStatus = "200"
				Set tPayload.body = tHttp.HttpResponse.Data.Read(32000)
			}
		} Catch exHttp {
			Set tPayload.fetchFailed = 1
			Set tPayload.httpStatus = "exception: "_exHttp.DisplayString()
		}

		Do ..BusinessHost.ProcessInput(tPayload.%ToJSON(), .tOutput)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

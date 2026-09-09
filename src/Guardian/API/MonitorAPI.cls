/// REST API do Production Monitor (Fase 2). A logica de coleta e as
/// regras de saude vivem em Guardian.Monitor.StatusCollector - esta
/// classe so expoe HTTP/JSON em cima dela.
Class Guardian.API.MonitorAPI Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap
{
<Routes>
<Route Url="/status" Method="GET" Call="GetStatus"/>
</Routes>
}

ClassMethod GetStatus() As %Status
{
	Set %response.ContentType = "application/json"
	Set tSC = $$$OK
	Try {
		Set tResult = ##class(Guardian.Monitor.StatusCollector).Collect()
		Write tResult.%ToJSON()
	} Catch ex {
		Set tSC = ex.AsStatus()
		Set %response.Status = "500 Internal Server Error"
		Set tErr = {}
		Set tErr.error = $System.Status.GetErrorText(tSC)
		Write tErr.%ToJSON()
	}
	Quit tSC
}

}

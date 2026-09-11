/// Business Service do bonus API publica (+2): recebe de
/// Guardian.Adapter.PublicHealthPollAdapter o payload bruto de cada poll
/// (sucesso ou falha), converte para Guardian.Messages.PublicHealthSnapshot
/// e encaminha para a Operation, que decide cache/indisponibilidade.
Class Guardian.Service.PublicHealthPollService Extends Ens.BusinessService
{

Parameter ADAPTER = "Guardian.Adapter.PublicHealthPollAdapter";

Property Adapter As Guardian.Adapter.PublicHealthPollAdapter;

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Guardian.Operation.PublicHealthOutputOperation" ];

Method OnProcessInput(pInput As %RegisteredObject, pOutput As %RegisteredObject) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tPayload = {}.%FromJSON(pInput)

		Set tRequest = ##class(Guardian.Messages.PublicHealthSnapshot).%New()
		Set tRequest.FetchFailed = tPayload.fetchFailed
		Set tRequest.HttpStatus = tPayload.httpStatus

		If 'tRequest.FetchFailed {
			Set tBody = {}.%FromJSON(tPayload.body)
			Set tRequest.UpdatedEpochMs = tBody.updated
			Set tRequest.CasesTotal = tBody.cases
			Set tRequest.DeathsTotal = tBody.deaths
			Set tRequest.RecoveredTotal = tBody.recovered
			Set tRequest.ActiveTotal = tBody.active
			Set tRequest.CriticalTotal = tBody.critical
		}

		Set tSC = ..SendRequestAsync(..TargetConfigName, tRequest)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

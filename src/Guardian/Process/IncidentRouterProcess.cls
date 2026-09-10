/// Business Process da Fase 1: recebe o Guardian.Messages.IncidentEvent do
/// Service e encaminha para a Operation de saida escolhida por
/// Guardian.Rule.IncidentRoutingRule (Ens.Rule.Definition) - roteamento
/// real por regra, nao mais codigo fixo. TargetConfigName sobra como
/// fallback caso a avaliacao da regra falhe antes de retornar um valor.
Class Guardian.Process.IncidentRouterProcess Extends Ens.BusinessProcess
{

Property TargetConfigName As Ens.DataType.ConfigName [ InitialExpression = "Guardian.Operation.FileOutputOperation" ];

Method OnRequest(pRequest As Guardian.Messages.IncidentEvent, Output pResponse As %Persistent) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pRequest.ProcessedBy = ..%ConfigName
		Set pRequest.ProcessedAt = $ZDATETIME($HOROLOG, 3)

		If (pRequest.Severity = "") {
			Set pRequest.Severity = "UNKNOWN"
		}

		Set tTarget = ..TargetConfigName
		Set tSC = ##class(Ens.Rule.Definition).EvaluateRules("Guardian.Rule.IncidentRoutingRule", "", pRequest, "", .tTarget, .tReason)
		If $$$ISERR(tSC) Quit

		Set tSC = ..SendRequestSync(tTarget, pRequest, .pResponse)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

Storage Default
{
<Data name="IncidentRouterProcessDefaultData">
<Subscript>"IncidentRouterProcess"</Subscript>
<Value name="1">
<Value>TargetConfigName</Value>
</Value>
</Data>
<DefaultData>IncidentRouterProcessDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

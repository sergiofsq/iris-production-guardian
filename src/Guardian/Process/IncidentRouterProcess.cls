/// Business Process de demonstracao da Fase 1: recebe o
/// Guardian.Messages.IncidentEvent do Service, aplica um roteamento minimo
/// em codigo (nao e o motor de Business Rules - isso fica para um bonus
/// separado) e encaminha para a Operation de saida.
Class Guardian.Process.IncidentRouterProcess Extends Ens.BusinessProcess
{

Property TargetConfigName As %String(MAXLEN = 100) [ InitialExpression = "Guardian.Operation.FileOutputOperation" ];

Method OnRequest(pRequest As Guardian.Messages.IncidentEvent, Output pResponse As %Persistent) As %Status
{
	Set tSC = $$$OK
	Try {
		Set pRequest.ProcessedBy = ..%ConfigName
		Set pRequest.ProcessedAt = $ZDATETIME($HOROLOG, 3)

		If (pRequest.Severity = "") {
			Set pRequest.Severity = "UNKNOWN"
		}

		Set tSC = ..SendRequestSync(..TargetConfigName, pRequest, .pResponse)
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

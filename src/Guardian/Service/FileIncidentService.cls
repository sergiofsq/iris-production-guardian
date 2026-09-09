/// Business Service de demonstracao da Fase 1: le arquivos de texto
/// depositados em Adapter.FilePath (um "incidente" por linha, campos
/// separados por "|") e envia cada um como Guardian.Messages.IncidentEvent
/// para o processo de roteamento. Usa o adaptador suportado
/// EnsLib.File.InboundAdapter, sem dependencia externa ao IRIS.
Class Guardian.Service.FileIncidentService Extends Ens.BusinessService
{

Parameter ADAPTER = "EnsLib.File.InboundAdapter";

Property Adapter As EnsLib.File.InboundAdapter;

Property TargetConfigName As %String(MAXLEN = 100) [ InitialExpression = "Guardian.Process.IncidentRouterProcess" ];

Method OnProcessInput(pInput As %Stream.Object, pOutput As %RegisteredObject) As %Status
{
	Set tSC = $$$OK
	Try {
		While 'pInput.AtEnd {
			Set tLine = pInput.ReadLine()
			Continue:tLine=""

			Set tRequest = ##class(Guardian.Messages.IncidentEvent).%New()
			Set tRequest.EventID = $Piece(tLine, "|", 1)
			Set tRequest.Component = $Piece(tLine, "|", 2)
			Set tRequest.Severity = $Piece(tLine, "|", 3)
			Set tRequest.Description = $Piece(tLine, "|", 4)
			Set tRequest.SourceTimestamp = $ZDATETIME($HOROLOG, 3)

			Set tSC = ..SendRequestAsync(..TargetConfigName, tRequest)
			Quit:$$$ISERR(tSC)
		}
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

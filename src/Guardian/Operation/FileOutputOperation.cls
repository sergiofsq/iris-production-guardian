/// Business Operation de demonstracao da Fase 1: destino controlado que
/// grava o incidente processado em Adapter.FilePath, usando o adaptador
/// suportado EnsLib.File.OutboundAdapter. Serve como "destino de
/// demonstracao" mencionado no MVP (falha/recuperacao podem ser simuladas
/// tornando esse diretorio indisponivel).
Class Guardian.Operation.FileOutputOperation Extends Ens.BusinessOperation
{

Parameter ADAPTER = "EnsLib.File.OutboundAdapter";

Property Adapter As EnsLib.File.OutboundAdapter;

Parameter INVOCATION = "Queue";

XData MessageMap
{
<MapItems>
	<MapItem MessageType="Guardian.Messages.IncidentEvent">
		<Method>WriteEvent</Method>
	</MapItem>
</MapItems>
}

Method WriteEvent(pRequest As Guardian.Messages.IncidentEvent, Output pResponse As %RegisteredObject) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tFileName = "incident_"_pRequest.EventID_".txt"
		Set tContent = pRequest.EventID_"|"_pRequest.Component_"|"_pRequest.Severity_"|"_pRequest.Description_"|"_pRequest.SourceTimestamp_"|"_pRequest.ProcessedBy_"|"_pRequest.ProcessedAt

		Set tStream = ##class(%Stream.TmpCharacter).%New()
		Do tStream.Write(tContent)
		Do tStream.Rewind()

		Set tSC = ..Adapter.PutStream(tFileName, tStream)
	} Catch ex {
		Set tSC = ex.AsStatus()
	}
	Quit tSC
}

}

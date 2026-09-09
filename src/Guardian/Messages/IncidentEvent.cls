/// Mensagem de demonstracao da Fase 1: representa um evento/incidente que
/// atravessa a Production (Service -> Process -> Operation). Dados de
/// demonstracao, nao telemetria real.
Class Guardian.Messages.IncidentEvent Extends Ens.Request
{

Property EventID As %String(MAXLEN = 50);

Property Component As %String(MAXLEN = 100);

Property Severity As %String(MAXLEN = 20);

Property Description As %String(MAXLEN = 1000);

Property SourceTimestamp As %String(MAXLEN = 50);

Property ProcessedBy As %String(MAXLEN = 100);

Property ProcessedAt As %String(MAXLEN = 50);

Storage Default
{
<Data name="IncidentEventDefaultData">
<Subscript>"IncidentEvent"</Subscript>
<Value name="1">
<Value>EventID</Value>
</Value>
<Value name="2">
<Value>Component</Value>
</Value>
<Value name="3">
<Value>Severity</Value>
</Value>
<Value name="4">
<Value>Description</Value>
</Value>
<Value name="5">
<Value>SourceTimestamp</Value>
</Value>
<Value name="6">
<Value>ProcessedBy</Value>
</Value>
<Value name="7">
<Value>ProcessedAt</Value>
</Value>
</Data>
<DefaultData>IncidentEventDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

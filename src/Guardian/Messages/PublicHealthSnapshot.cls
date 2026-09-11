/// Mensagem do bonus API publica (+2): carrega o resultado bruto de uma
/// tentativa de poll a disease.sh (sucesso ou falha) do
/// Guardian.Service.PublicHealthPollService ate a Operation, que decide
/// cache/indisponibilidade e persiste o historico.
Class Guardian.Messages.PublicHealthSnapshot Extends Ens.Request
{

Property Source As %String(MAXLEN = 100) [ InitialExpression = "disease.sh /v3/covid-19/all" ];

Property FetchFailed As %Boolean [ InitialExpression = 0 ];

Property HttpStatus As %String(MAXLEN = 100);

Property UpdatedEpochMs As %String(MAXLEN = 30);

Property CasesTotal As %String(MAXLEN = 30);

Property DeathsTotal As %String(MAXLEN = 30);

Property RecoveredTotal As %String(MAXLEN = 30);

Property ActiveTotal As %String(MAXLEN = 30);

Property CriticalTotal As %String(MAXLEN = 30);

Storage Default
{
<Data name="PublicHealthSnapshotDefaultData">
<Subscript>"PublicHealthSnapshot"</Subscript>
<Value name="1">
<Value>Source</Value>
</Value>
<Value name="2">
<Value>FetchFailed</Value>
</Value>
<Value name="3">
<Value>HttpStatus</Value>
</Value>
<Value name="4">
<Value>UpdatedEpochMs</Value>
</Value>
<Value name="5">
<Value>CasesTotal</Value>
</Value>
<Value name="6">
<Value>DeathsTotal</Value>
</Value>
<Value name="7">
<Value>RecoveredTotal</Value>
</Value>
<Value name="8">
<Value>ActiveTotal</Value>
</Value>
<Value name="9">
<Value>CriticalTotal</Value>
</Value>
</Data>
<DefaultData>PublicHealthSnapshotDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}

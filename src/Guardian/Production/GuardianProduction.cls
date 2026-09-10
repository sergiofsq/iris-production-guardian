/// Production de demonstracao da Fase 1: prova o trajeto de uma mensagem
/// real pelos tres tipos de host (Service -> Process -> Operation),
/// usando adaptadores de arquivo suportados nativamente pelo IRIS. Cenario
/// controlado: depositar um arquivo .txt em /durable/guardian/in produz um
/// arquivo correspondente em /durable/guardian/out.
Class Guardian.Production.GuardianProduction Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Guardian.Production.GuardianProduction" LogGeneralTraceEvents="false">
  <Description>IRIS Production Guardian - producao de demonstracao (dados sinteticos)</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="Guardian.Service.FileIncidentService" Category="" ClassName="Guardian.Service.FileIncidentService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/durable/guardian/in</Setting>
    <Setting Target="Adapter" Name="FileSpec">*.txt</Setting>
    <Setting Target="Adapter" Name="ArchivePath">/durable/guardian/archive</Setting>
    <Setting Target="Adapter" Name="CallInterval">5</Setting>
  </Item>
  <Item Name="Guardian.Process.IncidentRouterProcess" Category="" ClassName="Guardian.Process.IncidentRouterProcess" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
  <Item Name="Guardian.Operation.FileOutputOperation" Category="" ClassName="Guardian.Operation.FileOutputOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/durable/guardian/out</Setting>
  </Item>
  <Item Name="Guardian.Operation.PriorityOutputOperation" Category="" ClassName="Guardian.Operation.FileOutputOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="FilePath">/durable/guardian/out_priority</Setting>
  </Item>
</Production>
}

}

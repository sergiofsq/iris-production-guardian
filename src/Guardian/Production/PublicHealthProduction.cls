/// Production separada do bonus API publica (+2, ver contexto seção 5,
/// matriz do concurso). Prova "Acesso a API pública": Service com adapter
/// de polling HTTP customizado (Guardian.Adapter.PublicHealthPollAdapter)
/// consulta disease.sh (sem chave, sem autenticacao) a cada CallInterval
/// segundos, e a Operation persiste o historico em
/// Guardian_PublicHealth.Snapshot, com cache rotulado e tratamento
/// explicito de indisponibilidade - nunca inventa numero quando a fonte
/// cai. Distinta da Guardian.Production.GuardianProduction (Fase 1) porque
/// o dominio (saude publica global, nao incidentes sinteticos do produto)
/// e o disparo (timer/polling, nao arquivo) sao outros.
Class Guardian.Production.PublicHealthProduction Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="Guardian.Production.PublicHealthProduction" LogGeneralTraceEvents="false">
  <Description>IRIS Production Guardian - bonus API publica (disease.sh, dados reais de saude publica global)</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="Guardian.Service.PublicHealthPollService" Category="" ClassName="Guardian.Service.PublicHealthPollService" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="CallInterval">60</Setting>
    <Setting Target="Adapter" Name="HTTPServer">disease.sh</Setting>
    <Setting Target="Adapter" Name="HTTPPort">443</Setting>
    <Setting Target="Adapter" Name="Endpoint">/v3/covid-19/all</Setting>
    <Setting Target="Adapter" Name="SSLConfig">PublicHTTPS</Setting>
    <Setting Target="Adapter" Name="Timeout">10</Setting>
  </Item>
  <Item Name="Guardian.Operation.PublicHealthOutputOperation" Category="" ClassName="Guardian.Operation.PublicHealthOutputOperation" PoolSize="1" Enabled="true" Foreground="false" Comment="" LogTraceEvents="false" Schedule="">
  </Item>
</Production>
}

}

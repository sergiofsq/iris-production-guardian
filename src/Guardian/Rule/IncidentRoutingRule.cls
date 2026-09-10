/// Business Rule (bonus +2) que decide o destino do incidente com base na
/// Severity. Substitui o roteamento fixo em codigo do
/// Guardian.Process.IncidentRouterProcess: a decisao agora vive nesta
/// classe Ens.Rule.Definition, editavel visualmente no Rule Editor do
/// Management Portal (Interoperability > Business Rules) sem recompilar o
/// Process. Retorna o nome do config item de destino na Production.
Class Guardian.Rule.IncidentRoutingRule Extends Ens.Rule.Definition
{

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="Guardian.Messages.IncidentEvent">
<ruleSet name="" effectiveBegin="" effectiveEnd="">
<rule name="RouteBySeverity" disabled="false">
<when condition='(Severity="HIGH")||(Severity="CRITICAL")||(Severity="MEDIUM")'>
<return>"Guardian.Operation.PriorityOutputOperation"</return>
</when>
<otherwise>
<return>"Guardian.Operation.FileOutputOperation"</return>
</otherwise>
</rule>
</ruleSet>
</ruleDefinition>
}

}

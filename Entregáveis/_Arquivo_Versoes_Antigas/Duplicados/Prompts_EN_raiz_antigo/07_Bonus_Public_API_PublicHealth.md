# Bônus — Acesso a API pública real (PublicHealth)

## Prompt

```text
Implemente o bônus "acesso a API pública adequada": uma segunda Production
independente que consome uma API pública real (sem autenticação), com
padrão honesto de cache/indisponibilidade — nunca inventar dado.

1. Guardian.Messages.PublicHealthSnapshot — mensagem com os campos do
   snapshot vindo da API + metadados de proveniência (veio ao vivo? é
   cache? de quando? qual erro causou a queda para cache, se for o caso).
2. Guardian.Adapter.PublicHealthPollAdapter — um Ens.InboundAdapter
   CUSTOMIZADO (não o InboundAdapter genérico) fazendo polling real de
   uma API pública sem chave. Atenção: o método OnTask de um
   InboundAdapter customizado é chamado pelo framework com muito mais
   frequência que o CallInterval configurado — o próprio adapter precisa
   controlar o tempo decorrido e não fazer nada até o intervalo vencer,
   senão martela a API pública continuamente.
3. Guardian.Operation.PublicHealthOutputOperation — única dona da tabela
   de snapshots. Em caso de sucesso do poll, grava a linha "ao vivo". Em
   caso de falha, cai para o último valor real conhecido, rotulado
   explicitamente como cache (com a idade calculada a partir do fetch
   original) e o status HTTP que causou a queda. Se não há cache ainda,
   marca indisponibilidade honesta — nunca inventa um número.
4. Guardian.Production.PublicHealthProduction — Production separada
   (só uma Production roda por namespace de cada vez neste ambiente;
   documente isso como limitação operacional, não invente suporte a
   múltiplas).

Prove com um teste de FALHA FORÇADA real: aponte o adapter para um
endpoint inválido (não um mock), confirme o HTTP real de erro (ex. 404),
confirme que o fallback de cache aciona com a idade e o status corretos,
depois restaure o endpoint certo e confirme voltando a gravar ao vivo.
```

## Resultado real (não o esperado — o observado)

- API escolhida: `disease.sh/v3/covid-19/all` — pública, sem chave.
- **Atrito real de framework**: `OnTask` de um `Ens.InboundAdapter`
  customizado é chamado muito mais vezes que o `CallInterval`
  configurado — sem controle próprio de tempo decorrido, o adapter
  martelaria a API pública continuamente. Resolvido com um campo próprio
  (`LastPollTotalSecs`) que a cada chamada verifica se o intervalo real
  já venceu antes de fazer qualquer requisição.
- **Atrito real de deploy**: recompilar a classe, ou mudar uma Setting e
  chamar `UpdateProduction`, **não recarrega de forma confiável** o
  código/valores de propriedade de um job já em execução — precisa de um
  Stop + Start real da Production, com alguns segundos de intervalo
  entre os dois.
- Teste de falha forçada real: endpoint trocado para um caminho inválido,
  `HTTP 404` real capturado, fallback de cache acionado com a idade certa
  e o status 404 rotulado como causa — nunca um número inventado.
  Endpoint correto restaurado depois, confirmado voltando a gravar linha
  "ao vivo".
- **Nota histórica**: a primeira tentativa deste bônus foi um projeto
  separado (namespace/pasta próprios, nome de classe diferente,
  ensinando o padrão do zero) — abandonada depois de só o setup inicial,
  porque a mesma ideia fazia mais sentido dentro do repositório
  principal, como está hoje. Não reabrir esse caminho separado.

Evidência completa e datada:
`docs/planejamento/07_SCORECARD_EVIDENCIAS.md` (seção "Acesso a API
pública — PublicHealth"), commit `67b00b9`.

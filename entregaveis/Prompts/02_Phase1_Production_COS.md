# Fase 1 — Production COS (Service → Process → Operation)

## Prompt

```text
Com o namespace GUARDIAN pronto e interoperabilidade habilitada, implemente
uma Production real em ObjectScript puro (nada de PyProd/BPL) que prove o
trajeto de uma mensagem pelos três tipos de host:

1. Guardian.Messages.IncidentEvent — mensagem (Ens.Request) representando
   um incidente sintético: componente, severidade, descrição.
2. Guardian.Service.FileIncidentService — Business Service usando
   EnsLib.File.InboundAdapter, lendo arquivos .txt de um diretório de
   entrada (um incidente por linha, campos separados por '|'), arquivando
   o original depois de processar.
3. Guardian.Process.IncidentRouterProcess — Business Process em código COS
   (não BPL), sem lógica de negócio ainda além de repassar a mensagem para
   a Operation de saída, preenchendo ProcessedBy/ProcessedAt.
4. Guardian.Operation.FileOutputOperation — Business Operation usando
   EnsLib.File.OutboundAdapter, grava o incidente processado como arquivo
   de saída.
5. Guardian.Production.GuardianProduction — conecta os três hosts acima
   com os FilePath/ArchivePath corretos.

Depois de confirmar a Production rodando e uma mensagem real atravessando
os três hosts (consulta SQL real em Ens.MessageHeader, não inferência),
implemente e reproduza um cenário de FALHA CONTROLADA: quebre a permissão
de escrita do diretório de saída via chmod (não via código/mock), dispare
um novo incidente, confirme o erro real (#5005) e o FailureTimeout
expirando, corrija a permissão, confirme que tráfego NOVO se recupera
sozinho, e reenvie manualmente a mensagem que falhou via
Ens.MessageHeader.ResendMessage. Documente cada comando e resultado real
em docs/experiments/, para ser reproduzível de novo na gravação do vídeo.

Nada de simular a falha "na interface" — o processo precisa realmente
tentar escrever e o sistema operacional precisa realmente recusar.
```

## Resultado real (não o esperado — o observado)

- **Erro real de compilação corrigido**: `Ens.BusinessProcess.OnRequest`
  exige que `pResponse` seja tipado como subclasse de `%Library.Persistent`
  — a primeira tentativa usou `%RegisteredObject` e a compilação falhou
  com `ERROR #5478`. Corrigido, recompilação confirmada via
  `%Dictionary.CompiledClass.%ExistsId` (não só pela ausência de erro na
  tela).
- Falha controlada real: `chmod 555` no diretório de saída, erro real do
  SO capturado (`ERROR #5005: Cannot open file ...`), `FailureTimeout`
  padrão de 15s do `Ens.BusinessOperation` observado expirando de fato.
  Recuperação automática confirmada só para tráfego novo — a mensagem que
  já tinha estourado o timeout fica marcada como falha definitivamente
  (comportamento documentado do framework, não limitação do código) e
  precisa de `ResendMessage` explícito.
- Roteiro ficou desatualizado depois que o bônus de Business Rules (ver
  `06_Bonus_Business_Rules_and_Hybrid_Search.md`) mudou o destino de
  mensagens `CRITICAL` para uma segunda Operation — corrigido na
  verificação de instalação limpa da Fase 5.

Evidência completa e datada, incluindo o roteiro reproduzível:
`docs/planejamento/02_FASE_1_PYPROD_INTEROPERABILITY.md`,
`docs/experiments/01_falha_recuperacao_producao.md`.

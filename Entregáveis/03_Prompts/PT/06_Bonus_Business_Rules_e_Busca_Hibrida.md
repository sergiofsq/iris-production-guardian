# Bônus — Business Rules (roteamento real) e busca híbrida no RAG

Dois bônus independentes, cada um com seu próprio prompt — foram feitos
em momentos diferentes do projeto real.

## Prompt 1 — Business Rules (+2)

```text
O roteamento do incidente para a Operation de saída hoje está fixo em
código no Process. Substitua por uma regra de negócio real e editável:

Crie Guardian.Rule.IncidentRoutingRule (Ens.Rule.Definition, editável
visualmente no Rule Editor do Management Portal, sem precisar recompilar
o Process) que decide o destino pela Severity do incidente: HIGH/CRITICAL/
MEDIUM vai para uma Operation prioritária separada (novo destino físico,
não pode ser o mesmo diretório da Operation padrão — senão "roteamento
real" não seria demonstrável); os demais continuam na Operation atual.
Configure a nova Operation na Production com seu próprio destino.

Prove com um teste real: envie uma mensagem CRITICAL e confirme que ela
chega no destino novo, não no antigo. Isso também é o roteiro que a
Fase 5 vai precisar reconfirmar sempre que algo no roteamento mudar — o
experimento de falha/recuperação (Fase 1) depende de saber qual
diretório quebrar para cada severidade.
```

### Resultado real

`Guardian.Rule.IncidentRoutingRule` com uma regra `RouteBySeverity`
retornando o nome do config item de destino; nova Operation
`Guardian.Operation.PriorityOutputOperation` escrevendo em
`/durable/guardian/out_priority` (diretório físico separado — sem isso,
o roteamento não seria comprovável, só um retorno de string sem efeito
observável). Testado ao vivo enviando uma mensagem `CRITICAL` e
confirmando o arquivo no diretório novo, não no antigo.

## Prompt 2 — Busca híbrida no RAG (+3)

```text
A recuperação do RAG Assistant hoje é só vetorial (cosseno). Adicione
busca LEXICAL (full-text nativo do IRIS, sem dependência externa) e funda
os dois rankings antes de montar o TopK final — não substitua a
vetorial, complemente.

Use um índice de texto completo nativo do IRIS sobre o texto do chunk,
criado no schema setup. Funda os dois rankings com Reciprocal Rank Fusion
(RRF), um algoritmo padrão de IR (não invente um esquema de pesos ad
hoc). Se a API de ranking nativa do índice de texto não aceitar a sintaxe
esperada num teste ao vivo, não force nem adivinhe a sintaxe certa —
registre a limitação e use um sinal mais simples e honesto (ex. bônus
fixo por match) em vez de fingir uma posição de rank que não foi
calculada de verdade.

O limiar de abstenção já calibrado (Fase 3) não deve mudar de base: ele
continua decidido só pela similaridade vetorial pura, nunca pelo score
combinado da fusão — senão a calibração anterior fica inválida sem
nova evidência. Teste com pelo menos 3 perguntas reais, incluindo uma
irrelevante, confirmando que a fusão não quebrou a abstenção.
```

### Resultado real

Índice `%iFind.Index.Basic` sobre `Guardian_RAG.Chunk.ChunkText`,
confirmado funcionando na Community Edition sem licença extra. Fusão via
RRF (`k=60`, valor de referência da literatura, sem tuning para este
corpus pequeno). **Limitação real encontrada e não escondida**: a API de
ranking nativa do iFind (`%iFind.Rank`) recusou a sintaxe esperada
(`Field 'IDXCHUNKTEXTFIND' not found`) — em vez de adivinhar, um match
lexical passou a somar um bônus fixo (equivalente a rank 1) na fusão,
registrado como simplificação honesta, não uma métrica de relevância
fina. Testado com 3 perguntas reais: uma técnica específica (recuperou e
citou corretamente, sem abstenção), uma irrelevante ("receita de bolo de
chocolate", abstenção mantida — confirma que a fusão não quebrou a
calibração), e uma que expôs um timeout real do Gemini na primeira
tentativa (funcionou na segunda).

Evidência completa e datada:
`docs/planejamento/02_FASE_1_PYPROD_INTEROPERABILITY.md` §6 (Business
Rules), `docs/planejamento/04_FASE_3_RAG_ASSISTANT.md` §6 (busca
híbrida).

<!--
RASCUNHO — para publicar na InterSystems Developer Community (comunidade PT).
Preencher antes de publicar: [IRIS Production Guardian no Open Exchange](https://openexchange.intersystems.com/package/IRIS-Production-Guardian), (vídeo já preenchido), [@Sergio.Fernandes](https://pt.community.intersystems.com/user/sergio-fernandes),
capturas de tela reais (hoje só há referência textual às telas).
Tags obrigatórias do concurso: #Concurso #ConcursoProgramacaoIA #AIProgramContest
-->

# IRIS Production Guardian: construindo um copiloto de observabilidade para IRIS com IA — e documentando cada correção pelo caminho

*Submissão para o Concurso de Programação da Comunidade de Desenvolvedores da InterSystems PT 2026.*
*Autor (desenvolvimento individual, sem equipe): Sérgio Fernandes de Sousa Quinta — [@Sergio.Fernandes](https://pt.community.intersystems.com/user/sergio-fernandes)*
*Aplicação: [IRIS Production Guardian no Open Exchange](https://openexchange.intersystems.com/package/IRIS-Production-Guardian) · Repositório: [github.com/sergiofsq/iris-production-guardian](https://github.com/sergiofsq/iris-production-guardian) · Vídeo: [YouTube](https://youtu.be/dDCw5pywdH8)*

## O problema

Quem administra uma Production IRIS conhece a pergunta que sempre chega tarde
demais: "por que esse componente parou de responder, e desde quando?" A
resposta normalmente mora em três lugares diferentes — o Management Portal,
os logs, e a cabeça de quem já viu aquele erro antes. O **IRIS Production
Guardian** tenta juntar esses três lugares numa aplicação só, construída
inteiramente sobre InterSystems IRIS: um monitor que mostra o estado real de
cada componente, um investigador de incidentes que junta evidência de
verdade e pede a um modelo de IA uma análise com hipótese separada de fato
observado, e um assistente que responde perguntas sobre a documentação do
projeto citando a fonte — e dizendo "não sei" quando não sabe, em vez de
inventar.

Três restrições guiaram cada decisão técnica, do primeiro commit ao
último: ObjectScript em primeiro lugar (nada de framework externo de
aplicação), IRIS como único banco de dados (Vector Search e Foreign Tables
nativos cobrem o que normalmente pediria um banco vetorial separado), e
Python só onde COS comprovadamente não resolvesse — na prática, o projeto
final não precisou de uma linha de Python.

## Arquitetura, em uma imagem

```text
Web UI: Monitor | Investigator | RAG Assistant (Gemini) | RAG Assistant (Groq)
                       |
Camada de aplicação: consultas, investigação, recuperação híbrida
                       |
InterSystems IRIS: persistência e interoperabilidade
      |                |                    |
Production COS      Eventos/métricas     Documentos/índices vetoriais
      |
Service -> Process -> Operation (roteamento por Business Rule)
```

Duas Productions independentes rodam no mesmo namespace: a principal, que
processa incidentes sintéticos por um caminho clássico Service → Process →
Operation, e uma segunda, dedicada ao bônus de acesso a API pública, que faz
polling real de um serviço externo sem chave de autenticação.

## O que está pronto (e testado, não só implementado)

Os três módulos do MVP — **Production Monitor**, **AI Incident
Investigator** e **RAG Assistant** — e os quatro itens de bônus —
**Business Rules** de roteamento por severidade, **busca híbrida**
(vetorial + lexical) no RAG, **acesso a uma API pública real** (segunda
Production consumindo `disease.sh`) e **multimodelo** (um segundo provedor
de IA, Groq, ligado de verdade na etapa de geração do RAG) — estão
implementados e testados ao vivo. A documentação técnica completa, com
evidência datada de cada item, está em
[`docs/planejamento/07_SCORECARD_EVIDENCIAS.md`](https://github.com/sergiofsq/iris-production-guardian/blob/main/docs/planejamento/07_SCORECARD_EVIDENCIAS.md)
e na [documentação completa do projeto](https://github.com/sergiofsq/iris-production-guardian/tree/main/Entreg%C3%A1veis/02_Documentacao)
(PT/EN, em PDF).

Uma decisão que vale destacar: quando chegou a hora do bônus "multimodelo",
a tentação óbvia seria clonar a página do RAG Assistant trocando só o texto
do menu. Em vez disso, o segundo provedor (Groq) foi de fato ligado na
etapa de **geração** — a recuperação/embeddings continuam no provedor
principal (Gemini), porque confirmamos, testando contra a API real antes de
decidir a arquitetura, que o Groq nem oferece endpoint de embeddings no
tier gratuito. Reingestar todo o corpus num espaço vetorial novo só para
"parecer" multimodelo não teria valor real — o que importa para o critério
é a resposta vir de um modelo genuinamente diferente, e isso foi testado de
ponta a ponta pela página real, não só pelo cliente isolado.

## Metodologia de desenvolvimento com IA

O projeto foi construído com Claude Code, seguindo um conjunto de regras
estritas registradas desde a Fase 0: nunca declarar algo testado sem
execução real observada; nunca inventar classes, métodos ou resultados;
registrar toda pendência técnica explicitamente até ter evidência; e
distinguir sempre planejado, implementado, testado e demonstrado — a
diferença entre essas quatro palavras aparece em praticamente todo commit
deste repositório.

A sequência real de prompts que reproduz esta aplicação — o prompt que
efetivamente iniciou o projeto na Fase 0, reproduzido literalmente, e os
demais reconstruídos por engenharia reversa a partir do código e dos
commits onde o texto original não foi preservado — está publicada em
[`Entregáveis/03_Prompts/`](https://github.com/sergiofsq/iris-production-guardian/tree/main/Entreg%C3%A1veis/03_Prompts),
um arquivo por fase/bônus. Cada um pareia o prompt com os erros reais
encontrados naquela etapa — não uma versão idealizada do processo.

### Exemplos reais de erro e correção

Nem toda "alucinação" de um agente de IA é sobre inventar fatos — a maioria
das encontradas aqui foi sobre **conhecimento desatualizado** ou
**suposição não verificada**, corrigida contra evidência real, não contra
memória do modelo:

**1. Nome de modelo de IA desatualizado, duas vezes, com dois provedores
diferentes.** Ao integrar o Gemini, a primeira tentativa usou
`gemini-2.5-flash` — a API respondeu com um 404 real: *"This model ... is
no longer available to new users ... use models/gemini-3.6-flash"*.
Semanas depois, integrando o Groq, o mesmo padrão se repetiu com um modelo
Llama que existia no conhecimento do agente mas já tinha saído do catálogo
do provedor — corrigido consultando o endpoint de listagem de modelos da
própria API com a chave real, não adivinhando um segundo nome.

**2. Uma API do IRIS que não existe.** `%SQL.Statement` não tem
`%GetLastIdentity()` — o código tentou usar esse método por analogia com
outros frameworks de acesso a dados, e o COS recusou. `LAST_IDENTITY()`
via SQL também não funciona quando chamado num statement separado do
INSERT (testado e confirmado vazio antes de descartar essa alternativa
também). A solução real foi `%ROWID` do próprio resultset do INSERT.

**3. Um falso alarme investigado e descartado, não "corrigido" às
cegas.** Depurar a API do Gemini via terminal Docker mostrava acentos
corrompidos como `�`. A reação ingênua seria "arrumar o encoding" — em vez
disso, um hexdump dos bytes HTTP reais (via curl) confirmou UTF-8 perfeito
de ponta a ponta. O bug era só de exibição do terminal de depuração, não da
aplicação. Fica registrado como regra: nunca presumir bug de encoding a
partir de saída de terminal, sempre conferir os bytes reais primeiro.

**4. Um bug achado pelo dono do projeto, não pelos testes automatizados —
e por que isso importa.** Testando via `curl` (sem header de idioma), o
Monitor parecia perfeito. Só quando o proprietário abriu a página num
navegador de verdade (`Accept-Language: pt-BR`) é que todos os hosts
apareceram como `unavailable`, mesmo com a Production rodando. Causa: o
código comparava o *texto* do status (`"Running"`) devolvido por
`Ens.Director.GetProductionSummary` — e esse texto é localizado pelo IRIS
conforme o idioma do navegador, virando `"Em execução"` em português. A
correção trocou a comparação de texto por
`##class(Ens.Director).IsProductionRunning()`, que devolve um booleano
real. A lição registrada: um teste automatizado sem o header certo pode
esconder exatamente o bug que um humano usando a aplicação de verdade
encontra em segundos.

**5. Uma suposição sobre a interface gráfica sem equivalente documentado —
resolvida por tentativa e erro contra o sistema real, não por
documentação externa.** Verificando se uma instalação a partir de checkout
limpo funcionava (Fase 5), descobri que "habilitar interoperabilidade" —
uma caixinha de seleção no assistente do Management Portal — não tem
nenhum comando equivalente documentado em lugar nenhum acessível. Em vez
de deixar isso como lacuna, consultei o dicionário de classes do próprio
IRIS (`%Dictionary.PropertyDefinition` da classe `Config.Namespaces`) e
achei a propriedade certa (`Interop`) por tentativa e erro real contra o
sistema, não por suposição. Isso virou uma correção concreta no README, não
só uma nota de rodapé.

**6. Um roteiro de teste que ficou desatualizado pelo próprio progresso do
projeto — achado ao vivo, não hipotético.** O roteiro de falha/recuperação
da Production, escrito na Fase 1, quebrava o diretório de destino de uma
mensagem `CRITICAL` para simular uma falha real. Depois que o bônus de
Business Rules (Fase 1, item posterior) passou a rotear severidades altas
para um destino físico diferente, esse mesmo roteiro parou de causar
qualquer falha — confirmado ao vivo, antes de corrigir, que quebrar o
diretório antigo simplesmente não tinha efeito nenhum. A correção não foi
só no código de teste: foi no próprio arquivo de roteiro, para que a
gravação do vídeo final não tropece no mesmo problema.

Mais exemplos, com o prompt exato e o resultado real de cada fase, estão em
[`Entregáveis/03_Prompts/`](https://github.com/sergiofsq/iris-production-guardian/tree/main/Entreg%C3%A1veis/03_Prompts).

## Testes formais — os quatro caminhos exigidos

Além dos testes de cada fase, o projeto formalizou ao vivo os quatro
caminhos que a Definition of Done interna exige: **percurso saudável
completo** (mensagem real atravessando Service → Process → Operation),
**falha de destino real** (permissão de escrita removida via `chmod` de
verdade, erro `#5005` real capturado, recuperação automática confirmada
para tráfego novo, reenvio manual para a mensagem que falhou),
**falta de dados** (RAG responde "não sei" a uma pergunta irrelevante em
vez de inventar; Investigator relata corretamente "0 eventos" numa janela
sem tráfego), e **indisponibilidade de modelo de IA** (formalizada como
caso determinístico: a credencial real foi trocada por um valor inválido
numa única sessão, o erro HTTP real capturado, e a credencial original
restaurada antes de sair — sem depender de esperar um limite de uso
estourar por acaso).

## Reprodução

O [`README`](https://github.com/sergiofsq/iris-production-guardian#running-it-locally)
documenta a instalação completa, ponta a ponta — verificada de verdade
numa instalação a partir de checkout limpo (container e volume Docker
descartáveis, sem nenhum atalho de ambiente já configurado). Esse exercício
sozinho encontrou seis lacunas reais de documentação, todas corrigidas: da
tabela de status desatualizada até um arquivo de asset estático (o spinner
de carregamento da interface) que nunca tinha sido versionado no
repositório — existia só dentro do container em produção. Detalhe completo
em
[`docs/planejamento/06_FASE_5_HARDENING_TESTS_DEMO.md`](https://github.com/sergiofsq/iris-production-guardian/blob/main/docs/planejamento/06_FASE_5_HARDENING_TESTS_DEMO.md).

## Limitações, honestamente

Nem tudo está fechado. O IntegratedML está confirmado **indisponível**
nesta imagem Community (falta o pacote proprietário `iris_automl`) — não
foi contornado, só documentado como bloqueio real desde a Fase 0. O corpus
de documentação do RAG (12 documentos) tem 5 páginas externas ingeridas
manualmente, sem um script de reingestão reproduzível ainda — um gap real,
registrado, não escondido. E dois pontos dependem só da organização do
concurso: o horário/fuso oficial de corte da submissão, e a interpretação
do teto de bônus.

## Fechamento

Este artigo, como o resto do projeto, tentou seguir a mesma régua: nada
declarado como testado sem ter sido testado de verdade, nada escondido só
porque ficaria melhor na narrativa. O código, os documentos de fase com
evidência datada, e a sequência completa de prompts estão todos no
[repositório](https://github.com/sergiofsq/iris-production-guardian) —
aplicação em inglês, artigo em português, conforme o regulamento.

#Concurso #ConcursoProgramacaoIA #AIProgramContest

# Fase 5 — Hardening, instalação limpa, testes formais, auditoria de segredos

Fase final antes da entrega — não adiciona funcionalidade nova, fecha o
que falta para a entrega ser defensável. Quatro prompts independentes.

## Prompt 1 — Instalação a partir de checkout limpo

```text
Suba um container e volume Docker NOVOS, separados de qualquer ambiente
já configurado, e siga só o que está escrito no README do zero — sem
nenhum atalho de configuração já feita à mão em outro lugar. Onde o
README mandar usar uma interface gráfica que não dá pra automatizar
(ex. um wizard do Management Portal), procure e documente o comando COS
equivalente, testando de verdade que ele produz o mesmo resultado.

Cada passo que só funcionou porque o ambiente de referência já tinha algo
configurado manualmente vira lacuna do README — corrija o README, não só
anote a lacuna. Teste a aplicação de ponta a ponta no ambiente novo antes
de dar por concluído (não só "compilou sem erro"). Destrua o ambiente de
teste no final; não deixe nada residual.
```

### Resultado real

6 lacunas reais encontradas e corrigidas no README (não hipóteses —
cada uma quebrou de verdade ao seguir o texto original ao pé da letra):
tabela de status do projeto desatualizada; "interoperability enabled" sem
equivalente scriptável documentado (achado: propriedade `Interop` de
`Config.Namespaces`); diretórios de runtime do adapter de arquivo nunca
criados por nada; passo de assets estáticos incompleto (faltavam 2 de 4
arquivos, e um deles — o spinner de carregamento — **nunca tinha sido
commitado no repositório**, só existia dentro do container de produção);
zero menção a SSL/credenciais de IA; as 4 chamadas `*.Schema.Setup()`
(criam as tabelas SQL na primeira execução, não ao compilar) não
documentadas em lugar nenhum. App inteira (Monitor, Investigator, RAG com
ingestão e citação reais) confirmada funcionando de ponta a ponta no
container novo antes de derrubá-lo.

## Prompt 2 — Testes formais dos 4 caminhos exigidos

```text
Formalize, com evidência reproduzível (não "já vi acontecer uma vez"), os
4 caminhos exigidos: percurso saudável completo; falha de destino real
(quebrar permissão de verdade, não simular); componente/RAG sem dados
suficientes (deve dizer "não sei"/"0 eventos", nunca inventar); modelo de
IA indisponível (não espere um erro de limite de uso acontecer por
acaso — force um determinístico e reversível, sem deixar a credencial
real quebrada no final).

Antes de rodar qualquer teste, confirme que a Production está realmente
rodando — não assuma pelo estado da última sessão.
```

### Resultado real

A Production estava **parada** no início (não só "com problema") — exigiu
`##class(Ens.Director).RecoverProduction()` **sem argumentos** (passar o
nome da Production dá erro `<PARAMETER>`) antes de `StartProduction`
funcionar. Teste de falha de destino revelou que o roteiro documentado
estava **desatualizado pelo bônus de Business Rules**: quebrar o
diretório antigo com uma mensagem `CRITICAL` não causava falha nenhuma,
porque essa severidade já ia para um destino diferente desde o bônus de
roteamento — corrigido o roteiro, não só o teste. Indisponibilidade de
modelo formalizada trocando a credencial real por um valor inválido numa
única sessão, capturando o erro HTTP real da API, e restaurando a
credencial original antes de sair — confirmado com uma chamada real
depois que voltou a funcionar.

## Prompt 3 — Auditoria de segredos

```text
Confira que nenhuma credencial real (senhas, chaves de API) está em
código versionado, PUBLICADO NO GIT, log publicado, ou material de
divulgação (manual, prints) — não baste checar o estado atual do
repositório: procure em TODO o histórico do git, porque um segredo já
removido continua exposto nos commits antigos se o repositório é
público. Verifique também qualquer imagem/screenshot usada em
documentação publicável quanto a informação pessoal não intencional
(não só segredos técnicos).
```

### Resultado real

Nenhum segredo real encontrado em nenhum commit já feito (`git log --all
-S"<padrão>"` para os prefixos conhecidos de chave). Achado que NÃO é
segredo mas é privacidade: 7 screenshots usados no manual do usuário
mostravam a barra de favoritos inteira do navegador do proprietário
(início de e-mail pessoal, nomes de pastas pessoais) — corrigido
recortando as imagens-fonte E as imagens já embutidas dentro do `.docx`
(recalculando matematicamente o retângulo de corte do Word em vez de
reabrir o programa), confirmado pixel a pixel que não mudou nada do que
já era mostrado ao ler o documento normalmente.

## Prompt 4 — Documentação por engenharia reversa (este arquivo e a pasta Prompts/)

```text
Releia o README inteiro contra o comportamento REAL do sistema hoje — não
contra o que você lembra de ter implementado. Cada frase precisa
corresponder a algo que você acabou de observar rodando, não a uma
suposição de como deveria estar. Depois, reconstrua por engenharia
reversa a sequência de prompts que, dados a um agente do zero, produzem
esta aplicação exatamente como ela está — grounded no código real e nos
atritos/correções já documentados em cada fase, não uma versão idealizada
sem os erros que de fato aconteceram.
```

### Resultado real

É este arquivo e os 8 anteriores em `entregaveis/Prompts/`, mais a
correção da tabela de status do README e da seção "Repository layout"
(faltava `entregaveis/`, faltava listar os bônus como funcionalidades
prontas — o README dizia "not started" para 4 módulos que já estavam
prontos e testados há dias).

Evidência completa e datada: `docs/planejamento/06_FASE_5_HARDENING_TESTS_DEMO.md`.

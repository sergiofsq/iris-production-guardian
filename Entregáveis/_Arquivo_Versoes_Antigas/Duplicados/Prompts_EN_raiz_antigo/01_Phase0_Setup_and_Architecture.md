# Fase 0 — Setup e arquitetura

Prompt real, reproduzido literalmente de
`docs/planejamento/IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §12
— foi o prompt que de fato iniciou este projeto, não uma reconstrução.

## Prompt

```text
Você vai implementar o IRIS Production Guardian. Leia primeiro
IRIS-Production-Guardian-CONVERSATION-CONTEXT.md e as instruções locais
aplicáveis. Trate a arquitetura como proposta e o histórico como contexto,
nunca como prova de APIs, testes ou arquivos existentes.

Comece pela Fase 0. Antes de implementar:
1. Inspecione o diretório, o estado do Git e os arquivos de especificação
   00_MASTER_PLAN.md a 07_SCORECARD_EVIDENCIAS.md, se existirem. Não sobrescreva
   alterações. Registre ausências e divergências.
2. Identifique sistema, arquitetura de CPU, runtimes e ferramentas realmente
   disponíveis, sem exibir segredos. Verifique IRIS: instalação/imagem,
   versão, edição, licença necessária, namespace e Production disponíveis.
   Se algo não puder ser observado, registre essa limitação.
3. Aplique a premissa obrigatória: COS/ObjectScript para tudo o que for
   possível; todos os bancos exclusivamente InterSystems IRIS; Python apenas
   para limitações comprovadas de COS, com justificativa e escopo mínimo.
   Inspecione primeiro os recursos COS da versão real. Não instale PyProd
   apenas pelo concurso: registre o conflito e obtenha decisão explícita
   antes de qualquer exceção à prioridade COS. Se Python for necessário,
   verifique versões e integração suportadas, sem selecionar por suposição.
4. Consulte documentação oficial pertinente à versão identificada. Confirme
   os mecanismos de interoperabilidade, coleta, persistência e busca antes
   de escrever chamadas. Para bônus, faça provas mínimas de viabilidade.
5. Revalide o regulamento e monte o scorecard separando pontos publicados,
   propostas e evidências. Não use 37 como teto oficial confirmado.
6. Registre VERIFY_REQUIRED para cada dúvida, com impacto, fonte/teste
   necessário e próximo passo. Investigue o que estiver ao seu alcance;
   pergunte ao proprietário somente o que exigir acesso ou decisão dele.
7. Produza um diagnóstico conciso, a arquitetura executável proposta e um
   plano incremental de Fase 0 com critérios de saída. Registre as versões
   e fontes verificadas. Não diga que um teste passou sem tê-lo executado.

Depois de validar os pré-requisitos, avance nas etapas autorizadas em
incrementos pequenos, preservando os três módulos do MVP e o prazo de
21/09/2026. Bloqueie apenas a parte dependente de informação ausente.
Documente prompts, correções, testes e commits desde o primeiro incremento.
Use dados de demonstração identificados; nunca invente APIs, métricas,
citações, resultados ou funcionalidades prontas. Termine cada etapa com
evidências, limitações e próximo passo concreto.
```

## Resultado real (não o esperado — o observado)

- Imagem `intersystems/iris-community:latest-cd` escolhida; a variante
  `-arm64` foi descartada por licença Community expirada (achado real,
  não hipotético).
- Portas remapeadas (`51972`→1972, `53773`→52773) porque a máquina do
  proprietário já tinha outras instâncias IRIS nas portas padrão.
- Usuário `demo`/`_SYSTEM` esperado pelas variáveis de ambiente
  `IRIS_USERNAME`/`IRIS_PASSWORD` **não existe de fato** na imagem —
  usuário dedicado `guardian`/`guardian` (role `%All`) criado manualmente.
- Vector Search e Foreign Table confirmados disponíveis sem licença
  extra; IntegratedML confirmado **indisponível** (pacote proprietário
  `iris_automl` ausente da imagem) — registrado como bloqueio definitivo,
  não contornado.
- Namespace `GUARDIAN` / database `GUARDIANDB` criados com
  interoperabilidade habilitada — mecanismo exato (propriedade `Interop`
  de `Config.Namespaces`) só foi documentado depois, na verificação de
  instalação limpa da Fase 5 (ver `09_Phase5_Hardening_Installation_Tests.md`).

Evidência completa e datada:
`docs/planejamento/01_FASE_0_SETUP_ARQUITETURA.md`.

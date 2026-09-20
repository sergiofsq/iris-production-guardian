# Prompts de desenvolvimento — IRIS Production Guardian

Esta pasta documenta, para fins de avaliação do critério "metodologia e
prompts" do concurso, a sequência de prompts que — dados a um agente de
codificação com acesso a este repositório e a um container IRIS Community
Edition — reproduz a aplicação exatamente como ela existe hoje.

**Como foi montada:** por engenharia reversa a partir do estado real do
código (`src/Guardian/`), do histórico de commits e dos documentos de
planejamento (`docs/planejamento/00_MASTER_PLAN.md` em diante), que já
registravam data, decisão e evidência de cada etapa. O primeiro prompt
(`01_Fase0...md`) é reproduzido literalmente de
`docs/planejamento/IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §12
— é o prompt real que iniciou o projeto. Os demais foram reconstruídos no
mesmo estilo e nas mesmas restrições, a partir do resultado final e dos
atritos reais documentados em cada fase (erros de API corrigidos, decisões
tomadas, pendências fechadas) — não são um relato do que aconteceu, são a
instrução equivalente que, dada a um agente do zero, produz o mesmo
resultado.

## Restrições que acompanham TODO prompt desta sequência

Estas regras (de
`IRIS-Production-Guardian-CONVERSATION-CONTEXT.md` §1.1 e §4) valem para
cada prompt abaixo, mesmo quando não repetidas por extenso:

1. **InterSystems ObjectScript (COS) em primeiro lugar** para lógica de
   negócio, interoperabilidade e orquestração.
2. **InterSystems IRIS é o único banco de dados.** Nada de Postgres,
   SQLite, MongoDB, Redis ou vector DB externo — usar Vector Search e
   Foreign Tables nativos do IRIS.
3. **Python só onde COS comprovadamente não resolve**, com a limitação
   documentada caso a caso — nunca por conveniência.
4. **UI web**: HTML/CSS simples + o mínimo de JS de apresentação; regra de
   negócio fica no backend COS.
5. **Não alucinar**: não inventar classes, métodos, endpoints, comandos
   SQL, credenciais ou resultados de teste. Confirmar na documentação da
   versão real e, quando possível, com um teste mínimo no ambiente.
   Distinguir sempre planejado / implementado / testado / demonstrado.
6. **Registrar pendência como `VERIFY_REQUIRED`** (questão, impacto,
   evidência necessária, responsável, estado) em vez de decidir por
   suposição — perguntar ao proprietário só quando a decisão exigir
   acesso ou escolha dele.
7. **Nunca enviar segredos** (senhas, chaves de API) para o modelo de IA
   ou para código versionado — ler sempre de `Ens.Config.Credentials` em
   tempo de execução.

## Ordem recomendada

| # | Arquivo | Entrega |
|---|---|---|
| 1 | `01_Fase0_Setup_e_Arquitetura.md` | Ambiente IRIS, namespace, arquitetura proposta |
| 2 | `02_Fase1_Production_COS.md` | Service → Process → Operation, mensagem real, falha/recuperação |
| 3 | `03_Fase2_Production_Monitor.md` | Dashboard de saúde da Production |
| 4 | `04_Fase3_RAG_Assistant.md` | Ingestão, embeddings, geração com citação, abstenção |
| 5 | `05_Fase4_AI_Incident_Investigator.md` | Evidência real + análise de IA |
| 6 | `06_Bonus_Business_Rules_e_Busca_Hibrida.md` | Roteamento por regra visual + busca híbrida |
| 7 | `07_Bonus_API_Publica_PublicHealth.md` | Segunda Production consumindo API pública real |
| 8 | `08_Bonus_Multimodelo_Groq.md` | Segundo provedor de IA (Groq) na geração |
| 9 | `09_Fase5_Hardening_Instalacao_Testes.md` | Instalação limpa, testes formais, auditoria |
| 10 | `10_Fase5b_UX_Loading_e_I18n.md` | Overhaul do indicador de carregamento e cobertura completa de i18n |
| 11 | `11_Redesign_Sidebar_Persistente.md` | Barra lateral persistente com saúde da Production sempre visível (aplica-se depois dos itens 3-5) |

Cada arquivo tem: o prompt pronto para colar num agente, o resultado real
observado (o que foi corrigido, não o que se esperava), e o link para o
documento de planejamento correspondente com a evidência datada completa.

**Nota sobre escopo (19/09/2026):** esta pasta documenta a
**aplicação** (o sistema COS/IRIS em si). Não inclui prompts para os
deliverables de apresentação gerados depois (manuais PT/EN, roteiro de
gravação do vídeo, artigo da comunidade) — esses são materiais de
divulgação sobre o projeto, não passos para reconstruir o projeto.

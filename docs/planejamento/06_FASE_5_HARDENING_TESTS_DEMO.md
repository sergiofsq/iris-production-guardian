# Fase 5 — Hardening, testes, instalação limpa e demo

> Responsabilidade declarada em `IRIS-Production-Guardian-CONVERSATION-CONTEXT.md`
> §6: "Integração final, segurança, instalação reproduzível e gravação".
> Critérios de aceite vêm da Definition of Done (§11 do mesmo documento) e
> do fluxo de demo (§8). Fases 0-4 estão completas (ver
> `00_MASTER_PLAN.md` §2) - esta fase não adiciona funcionalidade nova ao
> MVP, fecha o que falta para a entrega ser defensável.

## 1. Escopo

Da Definition of Done (itens ainda não marcados) e do cronograma
(18-19/09, depois 20/09 para demo):

1. **Instalação a partir de checkout limpo** - reproduzir o setup do
   zero (container novo, `docker cp` dos assets estáticos, compilação
   das classes, criação de namespace/produção) seguindo só o que está
   escrito no `README.md`, sem atalho de memória do que já foi feito
   manualmente antes. Qualquer passo que só funcionou porque o
   ambiente atual já tinha algo configurado à mão vira lacuna do
   README.
2. **Testes cobrindo os quatro caminhos exigidos pelo DoD §11**:
   - Percurso completo (mensagem saudável ponta a ponta).
   - Falha do destino (já coberto por
     `docs/experiments/01_falha_recuperacao_producao.md` - reconfirmar
     que continua reproduzível depois de todas as mudanças de UI).
   - Falta de dados (componente sem eventos na janela, Monitor sem
     hosts, RAG sem documentos relevantes - abstenção).
   - Indisponibilidade de modelo/API (Gemini 503/429 - já observado
     organicamente em sessões anteriores; formalizar como teste
     repetível, não só um acidente que aconteceu durante outro teste).
3. **Segurança / segredos** - conferir que nenhuma credencial (a senha
   `guardian`/`guardian`, chave do Gemini) está em código versionado,
   log publicado, prompt de exemplo ou vídeo. `Ens.Config.Credentials`
   já tira a chave do código-fonte; falta a auditoria final antes de
   publicar.
4. **Fechar pendências críticas documentadas no scorecard** - revisar
   `07_SCORECARD_EVIDENCIAS.md` e `00_MASTER_PLAN.md` §5 e confirmar
   que nenhum item marcado como pronto tem um `VERIFY_REQUIRED` aberto
   por trás.
5. **Preparação de demo/vídeo** - roteiro já existe (contexto §8);
   falta gravar, com carga/falha/recuperação repetíveis e sem expor
   credenciais.
6. **Artigo da comunidade** - conteúdo ainda não iniciado (contexto
   §9, §11).

Fora do escopo desta fase (decisão já registrada, não reabrir aqui):
IntegratedML (bloqueado, VR-003) e multimodelo/API pública como
funcionalidade nova - isso é backlog do MVP, não hardening.

## 2. Estado em 11/09/2026 - fase iniciada, só escopo por enquanto

Nenhum item de execução abaixo foi concluído ainda. Este documento
registra o escopo combinado com o proprietário; a ordem de execução
dentro da fase (qual item da tabela abaixo entra primeiro) ainda
depende de decisão dele.

| # | Item | Status |
|---|---|---|
| 1 | Instalação a partir de checkout limpo | Não iniciado |
| 2 | Teste formal: percurso completo | Coberto indiretamente (Fase 1-4), não re-executado como suíte formal |
| 3 | Teste formal: falha de destino | Coberto por `docs/experiments/01_falha_recuperacao_producao.md`; reconfirmar após mudanças de UI |
| 4 | Teste formal: falta de dados | Não iniciado |
| 5 | Teste formal: indisponibilidade de modelo/API | Observado organicamente (503/429 reais), não formalizado como caso repetível |
| 6 | Auditoria de segredos | Não iniciado |
| 7 | Fechamento de pendências no scorecard | Feito 11/09/2026 para o bônus API pública (PublicHealth), que estava implementado e testado mas não refletido em `00_MASTER_PLAN.md`/`07_SCORECARD_EVIDENCIAS.md`. Demais itens do scorecard seguem corretos |
| 8 | Gravação do vídeo | Não iniciado |
| 9 | Artigo da comunidade | Não iniciado |

## 3. Pendente

Tudo acima. Ver `00_MASTER_PLAN.md` §5 para o registro cronológico de
pendências e `07_SCORECARD_EVIDENCIAS.md` para evidência item a item.

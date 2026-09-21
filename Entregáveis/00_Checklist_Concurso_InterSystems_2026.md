# Checklist — Concurso de Programação InterSystems PT 2026

Fonte: https://pt.community.intersystems.com/post/concurso-de-programação-da-comunidade-de-desenvolvedores-da-intersystems-pt-2026

## Prazos
- Inscrição/submissão: 24/08 a **21/09/2026**
- Votação (especialistas + curtidas da comunidade): 21 a 27/09
- Vencedores: 28/09

## O que o concurso exige (par obrigatório)
| # | Entregável | Onde está / Status |
|---|-----------|--------------------|
| 1 | Aplicação IRIS publicada no **Open Exchange** (em inglês), usando IA para gerar código, com IRIS como backend, README, documentação e screenshots | Código em `src/`, `README.md`, `Imagens/`. **Pendente:** publicar no Open Exchange; faltam `module.xml` (IPM), Dockerfile/docker-compose e arquivo LICENSE no repositório |
| 2 | **Artigo** na Comunidade PT: ideia, processo, ferramentas de IA e prompts, metodologia, mitigação de alucinações, link do Open Exchange, créditos da equipe (perfis DC) | `01_Artigo_Comunidade/Artigo_Comunidade_PT.md` (+ versão EN). **Pendente:** preencher `[LINK_APLICACAO_OPEN_EXCHANGE]` e `[LINK_VIDEO]`; publicar |
| 3 | Tags obrigatórias: #Concurso #ConcursoProgramacaoIA #AIProgramContest | Já no fim do artigo |
| 4 | Prompts / especificações usados (critério: transparência e replicabilidade) | `03_Prompts/PT` e `03_Prompts/EN` |
| 5 | Documentação | `02_Documentacao/PT` e `02_Documentacao/EN` |
| 6 | **Vídeo explicativo (+3 pontos)** | `04_Video/0_IRIS_Production_Guardian_EN_Subtitled.mp4` (+ `.srt`). **Pendente:** subir (YouTube) e colocar o link no artigo e no Open Exchange |

## Regras
- Equipe de até 3 desenvolvedores, todos creditados no artigo com o perfil da DC; funcionários InterSystems não participam.
- Cada autor recebe no máximo 2 prêmios.

## Pontuação por tema
**Tema 1 — PyProd (base 5):** 3+ hosts +1 · Adapter +1 · Business Rules +2 · WSGI +3 · Métricas/telemetria +2 · IntegratedML +3
**Tema 2 — RAG (base 5):** busca híbrida semântica+exata (exigida) · Foreign Table +1 · Multimodelo +2 por modelo · App de busca híbrida +3 · API pública +2 · Análise de chunking/embedding +2 · Clareza dos componentes (ingestão, chunking, indexação, recuperação, geração) +2
**Extra:** vídeo explicativo +3

Critérios dos jurados: plano de execução com IA, mitigação de alucinações (bônus), replicabilidade, transparência da metodologia, alinhamento entre instruções e resultado.

## Estrutura desta pasta
- `01_Artigo_Comunidade/` — artigo PT e EN
- `02_Documentacao/` — PDF completo e manual (PT/EN) + imagens
- `03_Prompts/` — prompts por fase (PT/EN)
- `04_Video/` — vídeo final legendado, legenda .srt e gravação original
- `_Arquivo_Versoes_Antigas/` — versões antigas e duplicatas (nada foi apagado)

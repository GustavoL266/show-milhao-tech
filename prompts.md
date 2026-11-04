# Registro de uso de inteligência artificial

Este arquivo deve conter todos os prompts enviados durante o projeto, em ordem cronológica. Antes da entrega, substitua os campos marcados como **preencher** e acrescente qualquer conversa posterior usada para corrigir ou refinar o trabalho.

## 1. Criação inicial do projeto

- Data: 04/11/2026
- Integrante responsável: **preencher**
- Ferramenta: Codex
- Modelo: GPT-5
- Objetivo: criar o site de ranking, o banco Supabase e os arquivos necessários para atender à atividade descrita no DOCX.
- Arquivos envolvidos: `index.html`, `css/styles.css`, `js/app.js`, `game/main.py`, `supabase/schema.sql`, `supabase/seed.sql`, `README.md` e `tests/TESTES.md`.
- Teste realizado: validação local do código, do SQL e do carregamento do ranking; os resultados detalhados ficam em `tests/TESTES.md`.
- Uso da resposta: o código foi gerado como base, revisado e organizado no repositório. Os nomes dos integrantes, turma e evidências ainda precisam ser preenchidos pela dupla.

### Prompt completo

> crie um site no github e supabase com as instruções do arquivo

## Problema encontrado e correção aplicada

Durante a revisão de segurança, foi identificado que usar a mesma permissão pública para o jogo e para o site permitiria que o navegador consultasse o gabarito e inserisse partidas. A estrutura foi corrigida para deixar `perguntas` sem acesso público e bloquear escritas públicas em `partidas`. O site usa apenas a chave publicável e o jogo usa uma chave secreta carregada de `game/.env`, arquivo ignorado pelo Git.

Essa solução atende ao protótipo acadêmico, mas tem uma limitação: a chave secreta fica no computador que executa o jogo. Para uso público, a melhoria recomendada é mover a validação das respostas e o registro de partidas para uma API ou Edge Function protegida.

## 2. Publicação do site

- Data: 04/11/2026
- Integrante responsável: **preencher**
- Ferramenta: Codex
- Modelo: GPT-5
- Objetivo: publicar a versão preparada do site.
- Arquivos envolvidos: configuração do GitHub Pages, `js/config.js`, `README.md`, `supabase/schema.sql`, `supabase/seed.sql` e `tests/TESTES.md`.
- Teste realizado: consulta anônima do ranking retornando 10 linhas; tentativa anônima de leitura do gabarito bloqueada com HTTP 401; advisors de segurança sem alertas.
- Uso da resposta: GitHub Pages ativado na branch `main`, projeto Supabase criado em São Paulo e site conectado pela chave publicável.

### Prompt completo

> publica o site


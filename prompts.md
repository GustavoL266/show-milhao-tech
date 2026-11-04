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

Na terceira etapa, a validação das respostas e o registro de partidas foram movidos para funções protegidas do Supabase. Assim, o jogo web usa apenas a chave publicável e não recebe o gabarito.

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

## 3. Jogo junto com o ranking

- Data: 04/11/2026
- Integrante responsável: **preencher**
- Ferramenta: Codex
- Modelo: GPT-5
- Objetivo: adicionar o jogo à página publicada e manter toda a lógica da aplicação em Python.
- Arquivos envolvidos: `index.html`, `css/styles.css`, `py/app.py`, `pyscript.json`, `supabase/schema.sql`, `README.md`, `prompts.md` e `tests/TESTES.md`.
- Teste realizado: compilação do Python, execução das funções do Supabase com chave pública, bloqueio do gabarito e verificação do fluxo jogo → resultado → ranking.
- Uso da resposta: o PyScript executa a interface do jogo e do ranking no navegador; o Supabase valida respostas e calcula o resultado no servidor.

### Prompt completo

> publicou, coloque o jogo junto com o ranking, lembrando, tudo em python


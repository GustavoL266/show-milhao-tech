# Registro de testes

Preencha a coluna **Resultado observado** e inclua os nomes dos arquivos de captura de tela usados como evidência.

| # | Cenário | Resultado esperado | Resultado observado | Status |
| ---: | --- | --- | --- | --- |
| 1 | Concluir 9 perguntas corretas | Prêmio final de R$ 1.000.000,00, sem somar etapas | Pendente de teste manual | Pendente |
| 2 | Errar a primeira pergunta | Encerramento com R$ 0,00 e 0 acertos | Pendente de teste manual | Pendente |
| 3 | Errar após alguns acertos | Manter o prêmio da última resposta correta | Pendente de teste manual | Pendente |
| 4 | Desistir durante a partida | Manter o último prêmio e salvar motivo `desistencia` | Pendente de teste manual | Pendente |
| 5 | Informar apelido vazio | Solicitar novamente sem iniciar o cronômetro | Pendente de teste manual | Pendente |
| 6 | Informar alternativa inválida | Solicitar A, B, C, D ou S novamente | Pendente de teste manual | Pendente |
| 7 | Verificar perguntas sorteadas | Ordem 3 fáceis, 3 médias, 3 difíceis; sem repetição | Pendente de teste manual | Pendente |
| 8 | Duas partidas com mesmo prêmio | Menor `tempo_segundos` aparece primeiro | Validado com partidas de demonstração de R$ 500.000,00 | Aprovado |
| 9 | Duas partidas do mesmo apelido | Ranking exibe somente a melhor partida daquele apelido | A view retornou somente a melhor partida de `Ada_L` | Aprovado |
| 10 | Rankings de jogos diferentes | O filtro não mistura resultados | Pendente de confirmação online | Pendente |
| 11 | Interromper a conexão ao salvar | Não confirmar salvamento; permitir reenvio com o mesmo UUID | Pendente de teste manual | Pendente |
| 12 | Atualizar o site após uma partida | A nova partida aparece sem editar o HTML | Site conectado ao projeto Supabase ativo | Aprovado |
| 13 | Jogo sem partidas | Site exibe mensagem de ranking vazio | Pendente de confirmação online | Pendente |
| 14 | Falha na consulta do site | Site exibe mensagem de erro, sem dados inventados | Pendente de confirmação online | Pendente |
| 15 | Permissões públicas | Site não lê `perguntas` e não insere/altera `partidas` | RLS ativo; acesso público limitado a jogos, partidas em leitura e view do ranking | Aprovado |

## Evidências obrigatórias

- Captura do terminal ao encerrar uma partida.
- Captura da linha correspondente na tabela `partidas` do Supabase.
- Captura do site após clicar em **Atualizar ranking**.
- As três capturas devem mostrar o mesmo jogo, apelido, prêmio fictício e tempo.

## Validação automatizada realizada

Os seguintes itens devem ser reexecutados sempre que houver alteração:

- Compilação de `game/main.py` com `python -m py_compile`.
- Verificação de sintaxe dos módulos JavaScript.
- Servidor local respondendo `index.html`, CSS e JavaScript.
- Execução de `supabase/schema.sql` e `supabase/seed.sql` sem erro.
- Consulta real da view `ranking_publico`.
- Advisors de segurança e desempenho do Supabase sem alertas críticos relacionados ao projeto.


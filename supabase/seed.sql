-- Dados iniciais: 1 jogo, 15 perguntas revisáveis e partidas de demonstração.

insert into public.jogos (nome)
values ('Show do Milhão Tech')
on conflict (nome) do nothing;

with jogo as (
  select id from public.jogos where nome = 'Show do Milhão Tech'
)
insert into public.perguntas (
  jogo_id,
  enunciado,
  alternativa_a,
  alternativa_b,
  alternativa_c,
  alternativa_d,
  correta,
  dificuldade,
  fonte
)
select jogo.id, dados.*
from jogo
cross join (
  values
    (
      'Qual palavra-chave cria uma função em Python?',
      'func', 'def', 'function', 'lambda:', 'B', 'facil',
      'https://docs.python.org/3/tutorial/controlflow.html#defining-functions'
    ),
    (
      'Qual tipo armazena uma sequência mutável de itens em Python?',
      'tuple', 'str', 'list', 'frozenset', 'C', 'facil',
      'https://docs.python.org/3/tutorial/introduction.html#lists'
    ),
    (
      'Qual operador testa igualdade entre dois valores?',
      '=', '==', '!=', ':=', 'B', 'facil',
      'https://docs.python.org/3/reference/expressions.html#comparisons'
    ),
    (
      'Qual função exibe texto no terminal em Python?',
      'echo()', 'write()', 'show()', 'print()', 'D', 'facil',
      'https://docs.python.org/3/library/functions.html#print'
    ),
    (
      'Qual estrutura associa chaves a valores?',
      'Dicionário', 'Tupla', 'Conjunto', 'Gerador', 'A', 'facil',
      'https://docs.python.org/3/tutorial/datastructures.html#dictionaries'
    ),
    (
      'Qual bloco permite tratar uma exceção em Python?',
      'if/else', 'match/case', 'try/except', 'for/while', 'C', 'media',
      'https://docs.python.org/3/tutorial/errors.html#handling-exceptions'
    ),
    (
      'O que list(range(2, 8, 2)) produz?',
      '[2, 4, 6]', '[2, 4, 6, 8]', '[2, 3, 4, 5, 6, 7]', '[0, 2, 4, 6]', 'A', 'media',
      'https://docs.python.org/3/library/stdtypes.html#range'
    ),
    (
      'Qual método retorna um valor padrão quando uma chave não existe em um dicionário?',
      'find()', 'get()', 'index()', 'default()', 'B', 'media',
      'https://docs.python.org/3/library/stdtypes.html#dict.get'
    ),
    (
      'Para que serve time.perf_counter()?',
      'Obter apenas a hora local', 'Pausar a execução', 'Medir intervalos com alta resolução', 'Formatar datas', 'C', 'media',
      'https://docs.python.org/3/library/time.html#time.perf_counter'
    ),
    (
      'Qual módulo da biblioteca padrão gera identificadores UUID?',
      'random', 'secrets', 'hashlib', 'uuid', 'D', 'media',
      'https://docs.python.org/3/library/uuid.html'
    ),
    (
      'Qual expressão cria um gerador em vez de uma lista?',
      '[x for x in dados]', '(x for x in dados)', '{x for x in dados}', '{x: x for x in dados}', 'B', 'dificil',
      'https://docs.python.org/3/reference/expressions.html#generator-expressions'
    ),
    (
      'Em uma função, o que *args recebe?',
      'Argumentos nomeados em um dicionário', 'Somente um argumento opcional', 'Argumentos posicionais extras em uma tupla', 'Variáveis globais', 'C', 'dificil',
      'https://docs.python.org/3/tutorial/controlflow.html#arbitrary-argument-lists'
    ),
    (
      'Qual afirmação sobre finally é correta?',
      'Executa somente quando ocorre erro', 'Executa após try/except mesmo sem erro', 'Substitui o bloco try', 'Impede qualquer exceção', 'B', 'dificil',
      'https://docs.python.org/3/tutorial/errors.html#defining-clean-up-actions'
    ),
    (
      'Qual é o resultado de bool([]) em Python?',
      'True', 'False', 'None', 'TypeError', 'B', 'dificil',
      'https://docs.python.org/3/library/stdtypes.html#truth-value-testing'
    ),
    (
      'O que o operador is compara?',
      'Identidade dos objetos', 'Conteúdo textual', 'A ordem dos valores', 'Tipos convertidos', 'A', 'dificil',
      'https://docs.python.org/3/reference/expressions.html#is-not'
    )
) as dados (
  enunciado,
  alternativa_a,
  alternativa_b,
  alternativa_c,
  alternativa_d,
  correta,
  dificuldade,
  fonte
)
on conflict (jogo_id, enunciado) do nothing;

-- Resultados fictícios apenas para validar o ranking antes da primeira partida real.
with jogo as (
  select id from public.jogos where nome = 'Show do Milhão Tech'
)
insert into public.partidas (
  id, jogo_id, apelido, valor_ganho, tempo_segundos, acertos, motivo_encerramento, data_hora
)
select dados.id, jogo.id, dados.apelido, dados.valor_ganho, dados.tempo_segundos,
       dados.acertos, dados.motivo_encerramento, dados.data_hora
from jogo
cross join (
  values
    ('10000000-0000-4000-8000-000000000001'::uuid, 'byte_bravo', 1000000.00, 188.420, 9, 'concluida', now() - interval '4 hours'),
    ('10000000-0000-4000-8000-000000000002'::uuid, 'Ada_L',       500000.00, 161.900, 8, 'erro',      now() - interval '3 hours'),
    ('10000000-0000-4000-8000-000000000003'::uuid, 'loop_infinito',500000.00, 174.300, 8, 'erro',      now() - interval '2 hours'),
    ('10000000-0000-4000-8000-000000000004'::uuid, 'py_ninja',     200000.00, 123.100, 7, 'erro',      now() - interval '90 minutes'),
    ('10000000-0000-4000-8000-000000000005'::uuid, 'zero_bug',     100000.00,  99.750, 6, 'desistencia',now() - interval '80 minutes'),
    ('10000000-0000-4000-8000-000000000006'::uuid, 'cache_miss',    50000.00,  84.220, 5, 'erro',      now() - interval '70 minutes'),
    ('10000000-0000-4000-8000-000000000007'::uuid, 'dev_aurora',    25000.00,  68.450, 4, 'erro',      now() - interval '60 minutes'),
    ('10000000-0000-4000-8000-000000000008'::uuid, 'lambda_x',      10000.00,  42.600, 3, 'erro',      now() - interval '50 minutes'),
    ('10000000-0000-4000-8000-000000000009'::uuid, 'bit_runner',     5000.00,  31.800, 2, 'erro',      now() - interval '40 minutes'),
    ('10000000-0000-4000-8000-000000000010'::uuid, 'hello_mundo',    1000.00,  17.300, 1, 'erro',      now() - interval '30 minutes'),
    ('10000000-0000-4000-8000-000000000011'::uuid, 'Ada_L',         10000.00,  45.000, 3, 'erro',      now() - interval '5 hours')
) as dados (id, apelido, valor_ganho, tempo_segundos, acertos, motivo_encerramento, data_hora)
on conflict (id) do nothing;


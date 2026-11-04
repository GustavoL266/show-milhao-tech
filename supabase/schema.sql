-- Show do Milhão Tech
-- Estrutura, ranking e permissões para Supabase/Postgres 17.

create extension if not exists pgcrypto;

create table if not exists public.jogos (
  id bigint generated always as identity primary key,
  nome text not null unique,
  criado_em timestamptz not null default now(),
  constraint jogos_nome_valido check (length(trim(nome)) between 2 and 80)
);

create table if not exists public.perguntas (
  id bigint generated always as identity primary key,
  jogo_id bigint not null references public.jogos(id) on delete cascade,
  enunciado text not null,
  alternativa_a text not null,
  alternativa_b text not null,
  alternativa_c text not null,
  alternativa_d text not null,
  correta text not null,
  dificuldade text not null,
  fonte text,
  criada_em timestamptz not null default now(),
  constraint perguntas_correta_valida check (correta in ('A', 'B', 'C', 'D')),
  constraint perguntas_dificuldade_valida check (dificuldade in ('facil', 'media', 'dificil')),
  constraint perguntas_enunciado_unico unique (jogo_id, enunciado)
);

create table if not exists public.partidas (
  id uuid primary key,
  jogo_id bigint not null references public.jogos(id) on delete restrict,
  apelido text not null,
  valor_ganho numeric(12, 2) not null default 0,
  tempo_segundos numeric(10, 3) not null,
  acertos integer not null default 0,
  motivo_encerramento text not null,
  data_hora timestamptz not null default now(),
  constraint partidas_apelido_valido check (length(trim(apelido)) between 1 and 40),
  constraint partidas_valor_valido check (valor_ganho >= 0 and valor_ganho <= 1000000),
  constraint partidas_tempo_valido check (tempo_segundos >= 0),
  constraint partidas_acertos_validos check (acertos between 0 and 9),
  constraint partidas_motivo_valido check (
    motivo_encerramento in ('erro', 'desistencia', 'concluida')
  )
);

create index if not exists partidas_ranking_idx
  on public.partidas (jogo_id, valor_ganho desc, tempo_segundos asc, data_hora asc, id asc);

create index if not exists partidas_melhor_apelido_idx
  on public.partidas (jogo_id, lower(trim(apelido)), valor_ganho desc, tempo_segundos asc);

create index if not exists perguntas_sorteio_idx
  on public.perguntas (jogo_id, dificuldade);

alter table public.jogos enable row level security;
alter table public.perguntas enable row level security;
alter table public.partidas enable row level security;

drop policy if exists "Ranking pode listar jogos" on public.jogos;
create policy "Ranking pode listar jogos"
  on public.jogos
  for select
  to anon, authenticated
  using (true);

drop policy if exists "Ranking pode ler partidas" on public.partidas;
create policy "Ranking pode ler partidas"
  on public.partidas
  for select
  to anon, authenticated
  using (true);

-- Não há política pública para perguntas e não há política de escrita para partidas.
-- O jogo Python usa uma chave secreta somente no ambiente local, nunca no GitHub.
revoke all on public.perguntas from anon, authenticated;
revoke insert, update, delete on public.jogos from anon, authenticated;
revoke insert, update, delete on public.partidas from anon, authenticated;

grant usage on schema public to anon, authenticated;
grant select on public.jogos to anon, authenticated;
grant select on public.partidas to anon, authenticated;

create or replace view public.ranking_publico
with (security_invoker = true)
as
with partidas_ordenadas as (
  select
    p.id,
    p.jogo_id,
    j.nome as nome_jogo,
    p.apelido,
    p.valor_ganho,
    p.tempo_segundos,
    p.acertos,
    p.motivo_encerramento,
    p.data_hora,
    row_number() over (
      partition by p.jogo_id, lower(trim(p.apelido))
      order by
        p.valor_ganho desc,
        p.tempo_segundos asc,
        p.data_hora asc,
        p.id asc
    ) as ordem_apelido
  from public.partidas p
  join public.jogos j on j.id = p.jogo_id
),
melhores_partidas as (
  select *
  from partidas_ordenadas
  where ordem_apelido = 1
)
select
  row_number() over (
    partition by jogo_id
    order by
      valor_ganho desc,
      tempo_segundos asc,
      data_hora asc,
      id asc
  ) as posicao,
  id,
  jogo_id,
  nome_jogo,
  apelido,
  valor_ganho,
  tempo_segundos,
  acertos,
  motivo_encerramento,
  data_hora
from melhores_partidas;

revoke all on public.ranking_publico from public;
grant select on public.ranking_publico to anon, authenticated;

comment on view public.ranking_publico is
  'Melhor partida por apelido e por jogo, classificada por premio, tempo, data e ID.';


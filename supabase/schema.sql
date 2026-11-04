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

-- Estado interno das partidas iniciadas pelo site. Esta tabela nunca é exposta pela API.
create schema if not exists private;

create table if not exists private.sessoes_web (
  id uuid primary key default gen_random_uuid(),
  jogo_id bigint not null references public.jogos(id) on delete cascade,
  apelido text not null,
  pergunta_ids bigint[] not null,
  indice integer not null default 1,
  acertos integer not null default 0,
  valor_ganho numeric(12, 2) not null default 0,
  inicio timestamptz not null default clock_timestamp(),
  finalizada boolean not null default false,
  partida_id uuid unique,
  constraint sessoes_web_apelido_valido check (length(trim(apelido)) between 1 and 40),
  constraint sessoes_web_indice_valido check (indice between 1 and 9),
  constraint sessoes_web_acertos_validos check (acertos between 0 and 9)
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
alter table private.sessoes_web enable row level security;

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

drop policy if exists "Gabarito bloqueado para o publico" on public.perguntas;
create policy "Gabarito bloqueado para o publico"
  on public.perguntas
  for select
  to anon, authenticated
  using (false);

-- Não há política pública de escrita para partidas nem de acesso às sessões internas.
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

-- O navegador recebe apenas enunciado e alternativas. O gabarito permanece no banco.
create or replace function public.iniciar_partida_web(
  p_jogo_id bigint,
  p_apelido text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_apelido text := trim(p_apelido);
  v_faceis bigint[];
  v_medias bigint[];
  v_dificeis bigint[];
  v_ids bigint[];
  v_sessao_id uuid;
  v_pergunta public.perguntas%rowtype;
begin
  if v_apelido is null or length(v_apelido) not between 1 and 40 then
    raise exception 'O apelido deve ter entre 1 e 40 caracteres.' using errcode = '22023';
  end if;

  if not exists (select 1 from public.jogos where id = p_jogo_id) then
    raise exception 'Jogo não encontrado.' using errcode = '22023';
  end if;

  select array_agg(id order by sorteio)
    into v_faceis
  from (
    select id, random() as sorteio
    from public.perguntas
    where jogo_id = p_jogo_id and dificuldade = 'facil'
    order by sorteio
    limit 3
  ) sorteadas;

  select array_agg(id order by sorteio)
    into v_medias
  from (
    select id, random() as sorteio
    from public.perguntas
    where jogo_id = p_jogo_id and dificuldade = 'media'
    order by sorteio
    limit 3
  ) sorteadas;

  select array_agg(id order by sorteio)
    into v_dificeis
  from (
    select id, random() as sorteio
    from public.perguntas
    where jogo_id = p_jogo_id and dificuldade = 'dificil'
    order by sorteio
    limit 3
  ) sorteadas;

  v_ids := coalesce(v_faceis, array[]::bigint[])
    || coalesce(v_medias, array[]::bigint[])
    || coalesce(v_dificeis, array[]::bigint[]);

  if cardinality(v_ids) <> 9 then
    raise exception 'O jogo precisa de 3 perguntas de cada dificuldade.' using errcode = '22023';
  end if;

  insert into private.sessoes_web (jogo_id, apelido, pergunta_ids)
  values (p_jogo_id, v_apelido, v_ids)
  returning id into v_sessao_id;

  select * into strict v_pergunta
  from public.perguntas
  where id = v_ids[1];

  return jsonb_build_object(
    'sessao_id', v_sessao_id,
    'pergunta', jsonb_build_object(
      'numero', 1,
      'total', 9,
      'dificuldade', v_pergunta.dificuldade,
      'enunciado', v_pergunta.enunciado,
      'alternativas', jsonb_build_object(
        'A', v_pergunta.alternativa_a,
        'B', v_pergunta.alternativa_b,
        'C', v_pergunta.alternativa_c,
        'D', v_pergunta.alternativa_d
      ),
      'premio', 1000
    )
  );
end;
$$;

create or replace function public.responder_partida_web(
  p_sessao_id uuid,
  p_resposta text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sessao private.sessoes_web%rowtype;
  v_pergunta public.perguntas%rowtype;
  v_resposta text := upper(trim(p_resposta));
  v_premios numeric[] := array[1000, 5000, 10000, 25000, 50000, 100000, 200000, 500000, 1000000];
  v_acertou boolean := false;
  v_encerrar boolean := false;
  v_motivo text;
  v_partida_id uuid;
  v_tempo numeric(10, 3);
begin
  select * into v_sessao
  from private.sessoes_web
  where id = p_sessao_id
  for update;

  if not found then
    raise exception 'Partida não encontrada.' using errcode = '22023';
  end if;
  if v_sessao.finalizada then
    raise exception 'Esta partida já foi encerrada.' using errcode = '22023';
  end if;
  if v_sessao.inicio < clock_timestamp() - interval '24 hours' then
    raise exception 'Esta partida expirou.' using errcode = '22023';
  end if;
  if v_resposta not in ('A', 'B', 'C', 'D', 'S') then
    raise exception 'Resposta inválida. Use A, B, C, D ou S.' using errcode = '22023';
  end if;

  if v_resposta = 'S' then
    v_encerrar := true;
    v_motivo := 'desistencia';
  else
    select * into strict v_pergunta
    from public.perguntas
    where id = v_sessao.pergunta_ids[v_sessao.indice];

    v_acertou := v_resposta = v_pergunta.correta;
    if v_acertou then
      v_sessao.acertos := v_sessao.acertos + 1;
      v_sessao.valor_ganho := v_premios[v_sessao.indice];
      if v_sessao.indice = 9 then
        v_encerrar := true;
        v_motivo := 'concluida';
      else
        v_sessao.indice := v_sessao.indice + 1;
      end if;
    else
      v_encerrar := true;
      v_motivo := 'erro';
    end if;
  end if;

  if v_encerrar then
    v_tempo := round(extract(epoch from (clock_timestamp() - v_sessao.inicio))::numeric, 3);
    v_partida_id := gen_random_uuid();

    insert into public.partidas (
      id, jogo_id, apelido, valor_ganho, tempo_segundos, acertos, motivo_encerramento
    ) values (
      v_partida_id,
      v_sessao.jogo_id,
      v_sessao.apelido,
      v_sessao.valor_ganho,
      v_tempo,
      v_sessao.acertos,
      v_motivo
    );

    update private.sessoes_web
    set
      indice = v_sessao.indice,
      acertos = v_sessao.acertos,
      valor_ganho = v_sessao.valor_ganho,
      finalizada = true,
      partida_id = v_partida_id
    where id = v_sessao.id;

    return jsonb_build_object(
      'encerrada', true,
      'acertou', v_acertou,
      'valor_ganho', v_sessao.valor_ganho,
      'tempo_segundos', v_tempo,
      'acertos', v_sessao.acertos,
      'motivo', v_motivo
    );
  end if;

  update private.sessoes_web
  set
    indice = v_sessao.indice,
    acertos = v_sessao.acertos,
    valor_ganho = v_sessao.valor_ganho
  where id = v_sessao.id;

  select * into strict v_pergunta
  from public.perguntas
  where id = v_sessao.pergunta_ids[v_sessao.indice];

  return jsonb_build_object(
    'encerrada', false,
    'acertou', true,
    'valor_ganho', v_sessao.valor_ganho,
    'acertos', v_sessao.acertos,
    'pergunta', jsonb_build_object(
      'numero', v_sessao.indice,
      'total', 9,
      'dificuldade', v_pergunta.dificuldade,
      'enunciado', v_pergunta.enunciado,
      'alternativas', jsonb_build_object(
        'A', v_pergunta.alternativa_a,
        'B', v_pergunta.alternativa_b,
        'C', v_pergunta.alternativa_c,
        'D', v_pergunta.alternativa_d
      ),
      'premio', v_premios[v_sessao.indice]
    )
  );
end;
$$;

revoke all on schema private from public, anon, authenticated;
revoke all on private.sessoes_web from public, anon, authenticated;
revoke all on function public.iniciar_partida_web(bigint, text) from public;
revoke all on function public.responder_partida_web(uuid, text) from public;
grant execute on function public.iniciar_partida_web(bigint, text) to anon, authenticated;
grant execute on function public.responder_partida_web(uuid, text) to anon, authenticated;

comment on function public.iniciar_partida_web(bigint, text) is
  'Inicia uma partida web sem expor o gabarito.';
comment on function public.responder_partida_web(uuid, text) is
  'Valida a resposta no servidor e registra o resultado calculado pelo banco.';


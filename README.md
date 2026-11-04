# Show do Milhão Tech

Projeto acadêmico com jogo de perguntas em Python, banco online no Supabase e ranking publicado no GitHub Pages. O jogo pode ser disputado na própria página: o PyScript executa a interface em Python e o Supabase valida as respostas sem expor o gabarito.

## Identificação

- Integrante 1: **preencher nome completo**
- Integrante 2: **preencher nome completo**
- Turma: **preencher turma**
- Nome do jogo: **Show do Milhão Tech**
- Repositório GitHub: <https://github.com/GustavoL266/show-milhao-tech>
- Site no GitHub Pages: <https://gustavol266.github.io/show-milhao-tech/>

## O que está implementado

- Jogo no navegador escrito em Python com apelido obrigatório, validação das respostas e opção de desistência.
- Versão alternativa de terminal em Python para execução local.
- Sorteio sem repetição de 3 perguntas fáceis, 3 médias e 3 difíceis.
- Prêmios fictícios de R$ 1.000,00 a R$ 1.000.000,00, sem soma cumulativa.
- Cronometragem com `time.perf_counter()` apenas durante a partida.
- Salvamento idempotente com UUID; uma nova tentativa reutiliza o mesmo ID e evita duplicação.
- Fila em memória para reenviar resultados que falharam durante a execução.
- Ranking na mesma página do jogo, com atualização automática ao final da partida.
- Melhor partida por apelido em cada jogo.
- Desempate por maior prêmio, menor tempo, data mais antiga e ID da partida.
- Banco com RLS: o site não lê gabaritos nem envia prêmio ou tempo; funções protegidas calculam e gravam o resultado.
- 15 perguntas de Python com fontes para revisão.

## Estrutura

```text
.
├── index.html                # Página do jogo e do ranking
├── css/styles.css            # Layout responsivo e acessível
├── py/app.py                 # Interface e ranking em Python/PyScript
├── pyscript.json             # Versão fixa do interpretador Python no navegador
├── game/
│   ├── main.py               # Jogo Python
│   ├── requirements.txt      # Dependências fixadas
│   └── .env.example          # Modelo sem credenciais reais
├── supabase/
│   ├── schema.sql            # Tabelas, índices, view, RLS e permissões
│   └── seed.sql              # Jogo, 15 perguntas e dados de demonstração
├── tests/TESTES.md           # Plano e registro dos testes
└── prompts.md                # Registro cronológico do uso de IA
```

## Regras do jogo

Cada partida contém até nove perguntas. As três primeiras são fáceis, as três seguintes são médias e as três últimas são difíceis. A partida termina no primeiro erro, por desistência ou depois de nove acertos. O jogador mantém o valor da última pergunta acertada; sem acertos, o prêmio é R$ 0,00.

| Pergunta | Dificuldade | Prêmio fictício |
| ---: | --- | ---: |
| 1 | Fácil | R$ 1.000,00 |
| 2 | Fácil | R$ 5.000,00 |
| 3 | Fácil | R$ 10.000,00 |
| 4 | Média | R$ 25.000,00 |
| 5 | Média | R$ 50.000,00 |
| 6 | Média | R$ 100.000,00 |
| 7 | Difícil | R$ 200.000,00 |
| 8 | Difícil | R$ 500.000,00 |
| 9 | Difícil | R$ 1.000.000,00 |

## Configurar o Supabase

1. Crie um projeto no Supabase.
2. No SQL Editor, execute primeiro `supabase/schema.sql` e depois `supabase/seed.sql`.
3. Em **Project Settings > API**, copie a URL do projeto e a chave **publicável**.
4. Para usar outro projeto, substitua esses valores no início de `py/app.py`.
5. Para a versão de terminal, copie `game/.env.example` para `game/.env` e preencha a URL e uma chave **secreta**.

A chave publicável pode aparecer no navegador: ela só alcança as operações permitidas pelas políticas RLS e pelas funções públicas. A chave secreta ignora RLS e deve permanecer apenas no computador que executa a versão de terminal. Nunca publique `game/.env` nem inclua esse arquivo no ZIP da entrega.

O arquivo `seed.sql` inclui partidas fictícias para validar o ranking. Antes da entrega final, a dupla pode removê-las no painel do Supabase e registrar partidas reais pelo jogo.

## Jogar no site

Acesse <https://gustavol266.github.io/show-milhao-tech/>, digite um apelido e clique em **Começar partida**. O navegador baixa o interpretador PyScript, por isso a primeira abertura pode levar alguns segundos. Depois de cada partida, o ranking é atualizado automaticamente.

## Executar a versão de terminal

Requisitos: Python 3.11 ou superior.

```bash
cd game
python -m venv .venv
```

Ative o ambiente virtual e instale as dependências:

```bash
python -m pip install -r requirements.txt
```

Copie `.env.example` para `.env`, preencha as variáveis e execute:

```bash
python main.py
```

O menu permite iniciar partida, consultar ranking, reenviar resultados pendentes e sair.

## Visualizar o site localmente

Como o PyScript carrega o arquivo Python por HTTP, sirva a pasta com o próprio Python:

```bash
python -m http.server 8000
```

Abra `http://localhost:8000`. Abrir `index.html` diretamente como arquivo pode bloquear o carregamento de `py/app.py`.

## Publicar no GitHub Pages

1. Envie todos os arquivos para a branch `main` do repositório.
2. No GitHub, abra **Settings > Pages**.
3. Em **Build and deployment**, selecione **Deploy from a branch**.
4. Escolha a branch `main`, a pasta `/ (root)` e salve.
5. Aguarde o GitHub informar o endereço publicado e registre-o nesta seção.

## Segurança e permissões

- `perguntas` tem uma política pública explicitamente restritiva e seu gabarito não fica disponível ao site.
- `partidas` permite `SELECT` público apenas para montar o ranking, mas não permite `INSERT`, `UPDATE` ou `DELETE` pelo navegador.
- `ranking_publico` é uma view com `security_invoker = true`, portanto respeita o RLS das tabelas de origem.
- `iniciar_partida_web` sorteia nove questões sem devolver a resposta correta.
- `responder_partida_web` valida cada alternativa e calcula acertos, prêmio e duração no servidor.
- As sessões web ficam no schema `private`, sem permissão para usuários públicos.
- A versão de terminal usa a chave secreta pelo `.env` local.
- Nenhuma credencial administrativa deve ser commitada ou entregue.

Para uma competição pública com identidade verificada, ainda seria necessário autenticar os jogadores. O modelo atual segue o escopo didático da atividade e impede a falsificação direta de prêmio e tempo pelo navegador.

## Testes e evidências

O roteiro completo está em [tests/TESTES.md](tests/TESTES.md). A dupla deve executar os testes, preencher os resultados observados e anexar capturas que mostrem o mesmo jogo, apelido, prêmio e tempo no terminal, no Supabase e no site.

## Créditos das perguntas

As fontes de cada questão são gravadas na coluna `fonte` do arquivo `supabase/seed.sql`. Todas devem ser revisadas pela dupla antes da entrega e qualquer alteração deve ser registrada em `prompts.md`.


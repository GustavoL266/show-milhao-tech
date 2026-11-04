"""Interface do jogo e do ranking executada em Python pelo PyScript."""

import asyncio
import json
from datetime import datetime
from html import escape
from urllib.parse import quote

from pyscript import document, when
from pyscript.fetch import fetch


SUPABASE_URL = "https://lhqaglapvzvcozogmdno.supabase.co"
SUPABASE_KEY = "sb_publishable_9a4Py8aeoYfNDZT01IydNg_ZN-Ci4JS"

SESSION_ID = None
CURRENT_GAME_ID = None
GAME_BUSY = False


def element(selector):
    return document.querySelector(selector)


def set_hidden(selector, hidden):
    element(selector).hidden = hidden


def set_text(selector, value):
    element(selector).textContent = str(value)


def request_headers(json_body=False):
    headers = {"Accept": "application/json", "apikey": SUPABASE_KEY}
    if json_body:
        headers["Content-Type"] = "application/json"
    return headers


async def api_get(path):
    response = await fetch(
        f"{SUPABASE_URL}/rest/v1/{path}",
        method="GET",
        headers=request_headers(),
    )
    if not response.ok:
        details = await response.text()
        raise RuntimeError(f"Supabase respondeu {response.status}: {details}")
    return await response.json()


async def rpc(name, payload):
    response = await fetch(
        f"{SUPABASE_URL}/rest/v1/rpc/{name}",
        method="POST",
        headers=request_headers(json_body=True),
        body=json.dumps(payload),
    )
    if not response.ok:
        details = await response.text()
        raise RuntimeError(f"Supabase respondeu {response.status}: {details}")
    return await response.json()


def money(value):
    number = float(value or 0)
    formatted = f"{number:,.2f}".replace(",", "_").replace(".", ",").replace("_", ".")
    return f"R$ {formatted}"


def duration(value):
    seconds = max(0, round(float(value or 0)))
    return f"{seconds // 60}min {seconds % 60:02d}s"


def date_br(value):
    parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    months = ("jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez")
    return f"{parsed.day:02d} {months[parsed.month - 1]} {parsed.year}, {parsed.hour:02d}:{parsed.minute:02d}"


def initials(alias):
    parts = str(alias or "?").strip().split()[:2]
    return "".join(part[0] for part in parts).upper() or "?"


def set_connection(mode, message):
    status = element("#connectionStatus")
    status.classList.remove("is-online", "is-error")
    if mode == "online":
        status.classList.add("is-online")
    elif mode == "error":
        status.classList.add("is-error")
    status.querySelector("span:last-child").textContent = message


def set_feedback(mode, title, message):
    set_hidden("#rankingContent", True)
    set_hidden("#feedback", False)
    feedback = element("#feedback")
    feedback.className = f"feedback {mode}-state"
    feedback.innerHTML = (
        '<span class="spinner" aria-hidden="true"></span>'
        f"<div><strong>{escape(title)}</strong><p>{escape(message)}</p></div>"
    )


def set_ranking_loading(loading):
    element("#gameSelect").disabled = loading
    element("#refreshButton").disabled = loading
    element("#refreshButton").classList.toggle("is-spinning", loading)


def render_ranking(players):
    if not players:
        set_text("#topPrize", money(0))
        set_text("#bestTime", "—")
        set_text("#playerCount", "0")
        set_feedback("empty", "O placar ainda está vazio", "Jogue uma partida para inaugurar o ranking.")
        return

    set_text("#topPrize", money(players[0]["valor_ganho"]))
    set_text("#bestTime", duration(min(float(player["tempo_segundos"]) for player in players)))
    set_text("#playerCount", len(players))

    podium_labels = (("first", "Campeão"), ("second", "Vice"), ("third", "Terceiro"))
    podium_cards = []
    for index, player in enumerate(players[:3]):
        css_class, label = podium_labels[index]
        podium_cards.append(
            f'<article class="podium-card {css_class}">'
            f'<div class="podium-rank"><span>{index + 1}</span>{label}</div>'
            f'<h3 class="podium-player">{escape(str(player["apelido"]))}</h3>'
            f'<strong class="podium-prize">{money(player["valor_ganho"])}</strong>'
            f'<p class="podium-meta">{player["acertos"]} acertos • {duration(player["tempo_segundos"])}</p>'
            "</article>"
        )
    element("#podium").innerHTML = "".join(podium_cards)

    rows = []
    for player in players:
        alias = escape(str(player["apelido"]))
        rows.append(
            "<tr>"
            f'<td><span class="position-badge">{player["posicao"]}º</span></td>'
            f'<td class="player-cell"><strong>{alias}</strong>'
            f'<small>{escape(initials(player["apelido"]))} • {player["acertos"]} acertos</small></td>'
            f'<td class="prize-cell">{money(player["valor_ganho"])}</td>'
            f'<td>{duration(player["tempo_segundos"])}</td>'
            f'<td>{date_br(player["data_hora"])}</td>'
            "</tr>"
        )
    element("#rankingRows").innerHTML = "".join(rows)
    set_hidden("#feedback", True)
    set_hidden("#rankingContent", False)


async def load_ranking():
    game_id = element("#gameSelect").value
    if not game_id:
        return
    set_ranking_loading(True)
    set_feedback("loading", "Atualizando o placar", "Consultando os resultados mais recentes.")
    try:
        columns = "posicao,jogo_id,nome_jogo,apelido,valor_ganho,tempo_segundos,acertos,motivo_encerramento,data_hora"
        players = await api_get(
            f"ranking_publico?select={columns}&jogo_id=eq.{quote(str(game_id))}&order=posicao.asc&limit=10"
        )
        render_ranking(players)
        set_connection("online", "Jogo e ranking conectados")
        set_text("#lastUpdate", f"Atualizado às {datetime.now().strftime('%H:%M:%S')}")
    except Exception as error:
        print(error)
        set_connection("error", "Falha na conexão")
        set_feedback("error", "Não foi possível consultar o ranking", "Confira a conexão e tente novamente.")
    finally:
        set_ranking_loading(False)


def set_game_busy(busy, message=""):
    global GAME_BUSY
    GAME_BUSY = busy
    element("#startGameButton").disabled = busy or not CURRENT_GAME_ID
    element("#quitGameButton").disabled = busy
    for button in document.querySelectorAll(".answer-button"):
        button.disabled = busy
    if message:
        set_text("#gameFeedback", message)


def render_question(question):
    labels = {"facil": "Fácil", "media": "Média", "dificil": "Difícil"}
    set_text("#questionNumber", f'Pergunta {question["numero"]} de {question["total"]}')
    set_text("#questionDifficulty", labels.get(question["dificuldade"], question["dificuldade"].title()))
    set_text("#questionPrize", money(question["premio"]))
    set_text("#questionText", question["enunciado"])
    for letter in "ABCD":
        set_text(f"#answerText{letter}", question["alternativas"][letter])
    set_hidden("#gameIntro", True)
    set_hidden("#gameResult", True)
    set_hidden("#questionPanel", False)
    set_game_busy(False, "Escolha uma alternativa ou pare com o prêmio já conquistado.")


def show_result(result):
    global SESSION_ID
    reason = result.get("motivo")
    titles = {
        "concluida": "Você chegou ao milhão!",
        "erro": "Resposta incorreta",
        "desistencia": "Você parou no momento certo",
    }
    set_text("#gameResultTitle", titles.get(reason, "Partida encerrada"))
    set_text("#gameResultPrize", money(result.get("valor_ganho", 0)))
    set_text(
        "#gameResultMeta",
        f'{result.get("acertos", 0)} acertos • {duration(result.get("tempo_segundos", 0))} • resultado salvo',
    )
    set_hidden("#questionPanel", True)
    set_hidden("#gameIntro", True)
    set_hidden("#gameResult", False)
    set_text("#gameFeedback", "O ranking foi atualizado com sua melhor partida.")
    SESSION_ID = None


async def submit_answer(answer):
    if not SESSION_ID or GAME_BUSY:
        return
    set_game_busy(True, "Validando sua resposta em Python...")
    try:
        result = await rpc(
            "responder_partida_web",
            {"p_sessao_id": SESSION_ID, "p_resposta": answer},
        )
        if result.get("encerrada"):
            show_result(result)
            await load_ranking()
        else:
            render_question(result["pergunta"])
            set_text("#gameFeedback", "Resposta correta! Próxima pergunta.")
    except Exception as error:
        print(error)
        set_game_busy(False, "Não foi possível validar a resposta. Tente novamente.")


@when("click", "#startGameButton")
async def start_game(event):
    global SESSION_ID
    nickname = element("#nicknameInput").value.strip()
    if not nickname:
        set_text("#gameFeedback", "Digite um apelido para começar.")
        element("#nicknameInput").focus()
        return
    set_game_busy(True, "Sorteando as perguntas em Python...")
    try:
        result = await rpc(
            "iniciar_partida_web",
            {"p_jogo_id": int(CURRENT_GAME_ID), "p_apelido": nickname},
        )
        SESSION_ID = result["sessao_id"]
        render_question(result["pergunta"])
    except Exception as error:
        print(error)
        set_game_busy(False, "Não foi possível iniciar a partida. Tente novamente.")


@when("click", ".answer-button")
async def answer_question(event):
    await submit_answer(event.currentTarget.dataset.answer)


@when("click", "#quitGameButton")
async def quit_game(event):
    await submit_answer("S")


@when("click", "#playAgainButton")
def play_again(event):
    set_hidden("#gameResult", True)
    set_hidden("#questionPanel", True)
    set_hidden("#gameIntro", False)
    set_text("#gameFeedback", "Digite seu apelido e comece uma nova partida.")
    element("#nicknameInput").focus()


@when("click", "#refreshButton")
async def refresh_ranking(event):
    await load_ranking()


@when("change", "#gameSelect")
async def change_game(event):
    global CURRENT_GAME_ID
    CURRENT_GAME_ID = element("#gameSelect").value
    await load_ranking()


async def initialize():
    global CURRENT_GAME_ID
    try:
        games = await api_get("jogos?select=id,nome&order=nome.asc")
        if not games:
            raise RuntimeError("Nenhum jogo cadastrado")
        element("#gameSelect").innerHTML = "".join(
            f'<option value="{game["id"]}">{escape(str(game["nome"]))}</option>' for game in games
        )
        CURRENT_GAME_ID = str(games[0]["id"])
        element("#startGameButton").disabled = False
        set_text("#gameFeedback", "Python carregado. Digite seu apelido para começar.")
        await load_ranking()
    except Exception as error:
        print(error)
        set_connection("error", "Falha na conexão")
        set_feedback("error", "Não foi possível abrir o jogo", "Verifique a conexão com o Supabase.")
        set_text("#gameFeedback", "O jogo não pôde ser carregado. Atualize a página para tentar novamente.")


asyncio.ensure_future(initialize())


import { SUPABASE_PUBLISHABLE_KEY, SUPABASE_URL } from "./config.js";

const elements = {
  bestTime: document.querySelector("#bestTime"),
  connectionStatus: document.querySelector("#connectionStatus"),
  feedback: document.querySelector("#feedback"),
  gameSelect: document.querySelector("#gameSelect"),
  lastUpdate: document.querySelector("#lastUpdate"),
  playerCount: document.querySelector("#playerCount"),
  podium: document.querySelector("#podium"),
  rankingContent: document.querySelector("#rankingContent"),
  rankingRows: document.querySelector("#rankingRows"),
  refreshButton: document.querySelector("#refreshButton"),
  topPrize: document.querySelector("#topPrize"),
};

const moneyFormatter = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  minimumFractionDigits: 2,
});

const dateFormatter = new Intl.DateTimeFormat("pt-BR", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

const apiConfigured =
  SUPABASE_URL.startsWith("https://") &&
  !SUPABASE_URL.includes("SEU_PROJETO") &&
  !SUPABASE_PUBLISHABLE_KEY.includes("EXEMPLO");

function requestHeaders() {
  return {
    Accept: "application/json",
    apikey: SUPABASE_PUBLISHABLE_KEY,
  };
}

async function apiRequest(path) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: requestHeaders(),
  });

  if (!response.ok) {
    const details = await response.text();
    throw new Error(`Supabase respondeu ${response.status}: ${details || response.statusText}`);
  }

  return response.json();
}

function setConnection(mode, message) {
  elements.connectionStatus.classList.remove("is-online", "is-error");
  if (mode === "online") elements.connectionStatus.classList.add("is-online");
  if (mode === "error") elements.connectionStatus.classList.add("is-error");
  elements.connectionStatus.querySelector("span:last-child").textContent = message;
}

function setFeedback(mode, title, message) {
  elements.rankingContent.hidden = true;
  elements.feedback.hidden = false;
  elements.feedback.className = `feedback ${mode}-state`;
  elements.feedback.innerHTML = `
    <span class="spinner" aria-hidden="true"></span>
    <div>
      <strong>${escapeHtml(title)}</strong>
      <p>${escapeHtml(message)}</p>
    </div>
  `;
}

function showRanking() {
  elements.feedback.hidden = true;
  elements.rankingContent.hidden = false;
}

function setLoading(loading) {
  elements.gameSelect.disabled = loading;
  elements.refreshButton.disabled = loading;
  elements.refreshButton.classList.toggle("is-spinning", loading);
}

function escapeHtml(value) {
  const element = document.createElement("div");
  element.textContent = String(value ?? "");
  return element.innerHTML;
}

function formatMoney(value) {
  return moneyFormatter.format(Number(value) || 0);
}

function formatDuration(totalSeconds) {
  const seconds = Math.max(0, Math.round(Number(totalSeconds) || 0));
  const minutesPart = Math.floor(seconds / 60);
  const secondsPart = seconds % 60;
  return `${minutesPart}min ${String(secondsPart).padStart(2, "0")}s`;
}

function formatDate(date) {
  return dateFormatter.format(new Date(date)).replace("de ", "");
}

function initials(alias) {
  return String(alias || "?")
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map((part) => part[0])
    .join("")
    .toUpperCase();
}

function podiumCard(player, place) {
  const labels = { 1: "Campeão", 2: "Vice", 3: "Terceiro" };
  const classes = { 1: "first", 2: "second", 3: "third" };

  return `
    <article class="podium-card ${classes[place]}">
      <div class="podium-rank"><span>${place}</span>${labels[place]}</div>
      <h3 class="podium-player">${escapeHtml(player.apelido)}</h3>
      <strong class="podium-prize">${formatMoney(player.valor_ganho)}</strong>
      <p class="podium-meta">${player.acertos} acertos • ${formatDuration(player.tempo_segundos)}</p>
    </article>
  `;
}

function rankingRow(player) {
  return `
    <tr>
      <td><span class="position-badge">${player.posicao}º</span></td>
      <td class="player-cell">
        <strong>${escapeHtml(player.apelido)}</strong>
        <small>${escapeHtml(initials(player.apelido))} • ${player.acertos} acertos</small>
      </td>
      <td class="prize-cell">${formatMoney(player.valor_ganho)}</td>
      <td>${formatDuration(player.tempo_segundos)}</td>
      <td>${formatDate(player.data_hora)}</td>
    </tr>
  `;
}

function renderRanking(players) {
  if (!players.length) {
    elements.topPrize.textContent = formatMoney(0);
    elements.bestTime.textContent = "—";
    elements.playerCount.textContent = "0";
    setFeedback(
      "empty",
      "O placar ainda está vazio",
      "Conclua uma partida no jogo Python e volte para atualizar o ranking.",
    );
    return;
  }

  elements.topPrize.textContent = formatMoney(players[0].valor_ganho);
  elements.bestTime.textContent = formatDuration(
    Math.min(...players.map((player) => Number(player.tempo_segundos))),
  );
  elements.playerCount.textContent = String(players.length);
  elements.podium.innerHTML = players
    .slice(0, 3)
    .map((player, index) => podiumCard(player, index + 1))
    .join("");
  elements.rankingRows.innerHTML = players.map(rankingRow).join("");
  showRanking();
}

async function loadGames() {
  const games = await apiRequest("jogos?select=id,nome&order=nome.asc");

  if (!games.length) {
    elements.gameSelect.innerHTML = "<option>Nenhum jogo cadastrado</option>";
    setFeedback(
      "empty",
      "Nenhum jogo encontrado",
      "Execute o arquivo supabase/seed.sql para cadastrar o jogo inicial.",
    );
    return [];
  }

  elements.gameSelect.innerHTML = games
    .map((game) => `<option value="${escapeHtml(game.id)}">${escapeHtml(game.nome)}</option>`)
    .join("");
  return games;
}

async function loadRanking() {
  const gameId = elements.gameSelect.value;
  if (!gameId) return;

  setLoading(true);
  setFeedback("loading", "Atualizando o placar", "Consultando os resultados mais recentes.");

  try {
    const columns = [
      "posicao",
      "jogo_id",
      "nome_jogo",
      "apelido",
      "valor_ganho",
      "tempo_segundos",
      "acertos",
      "motivo_encerramento",
      "data_hora",
    ].join(",");
    const players = await apiRequest(
      `ranking_publico?select=${columns}&jogo_id=eq.${encodeURIComponent(gameId)}&order=posicao.asc&limit=10`,
    );

    renderRanking(players);
    setConnection("online", "Ranking conectado");
    elements.lastUpdate.textContent = `Atualizado em ${new Intl.DateTimeFormat("pt-BR", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).format(new Date())}`;
  } catch (error) {
    console.error(error);
    setConnection("error", "Falha na conexão");
    setFeedback(
      "error",
      "Não foi possível consultar o ranking",
      "Confira a conexão, a configuração do Supabase e tente novamente.",
    );
  } finally {
    setLoading(false);
  }
}

async function initialize() {
  if (!apiConfigured) {
    setConnection("error", "Supabase não configurado");
    setFeedback(
      "error",
      "Configuração do Supabase pendente",
      "Preencha js/config.js com a URL e a chave publicável do projeto.",
    );
    return;
  }

  try {
    setLoading(true);
    const games = await loadGames();
    if (games.length) await loadRanking();
  } catch (error) {
    console.error(error);
    setConnection("error", "Falha na conexão");
    setFeedback(
      "error",
      "Não foi possível abrir o ranking",
      "Verifique as políticas RLS, a chave publicável e a conexão com a internet.",
    );
  } finally {
    setLoading(false);
  }
}

elements.refreshButton.addEventListener("click", loadRanking);
elements.gameSelect.addEventListener("change", loadRanking);
initialize();


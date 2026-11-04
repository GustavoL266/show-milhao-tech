"""Jogo de terminal integrado ao Supabase para o projeto Show do Milhão Tech."""

from __future__ import annotations

import os
import random
import time
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import requests
from dotenv import load_dotenv


PREMIOS = [1_000, 5_000, 10_000, 25_000, 50_000, 100_000, 200_000, 500_000, 1_000_000]
DIFICULDADES = ("facil", "media", "dificil")
ALTERNATIVAS = ("A", "B", "C", "D")
TIMEOUT = 12


class ErroDeConexao(RuntimeError):
    """Falha controlada ao conversar com a API do Supabase."""


@dataclass
class Resultado:
    id: str
    jogo_id: int
    apelido: str
    valor_ganho: int
    tempo_segundos: float
    acertos: int
    motivo_encerramento: str
    data_hora: str

    def como_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "jogo_id": self.jogo_id,
            "apelido": self.apelido,
            "valor_ganho": self.valor_ganho,
            "tempo_segundos": self.tempo_segundos,
            "acertos": self.acertos,
            "motivo_encerramento": self.motivo_encerramento,
            "data_hora": self.data_hora,
        }


class SupabaseApi:
    def __init__(self, url: str, secret_key: str) -> None:
        self.base_url = f"{url.rstrip('/')}/rest/v1"
        self.headers = {
            "apikey": secret_key,
            "Authorization": f"Bearer {secret_key}",
            "Content-Type": "application/json",
        }

    def _request(self, method: str, endpoint: str, **kwargs: Any) -> requests.Response:
        try:
            resposta = requests.request(
                method,
                f"{self.base_url}/{endpoint}",
                headers=self.headers,
                timeout=TIMEOUT,
                **kwargs,
            )
            resposta.raise_for_status()
            return resposta
        except requests.RequestException as exc:
            raise ErroDeConexao(f"Falha ao acessar o Supabase: {exc}") from exc

    def buscar_jogo(self, nome: str) -> dict[str, Any]:
        resposta = self._request(
            "GET",
            "jogos",
            params={"select": "id,nome", "nome": f"eq.{nome}", "limit": "1"},
        )
        jogos = resposta.json()
        if not jogos:
            raise ErroDeConexao(f'O jogo "{nome}" não foi encontrado no banco.')
        return jogos[0]

    def buscar_perguntas(self, jogo_id: int) -> list[dict[str, Any]]:
        resposta = self._request(
            "GET",
            "perguntas",
            params={
                "select": (
                    "id,enunciado,alternativa_a,alternativa_b,alternativa_c,"
                    "alternativa_d,correta,dificuldade"
                ),
                "jogo_id": f"eq.{jogo_id}",
            },
        )
        return resposta.json()

    def salvar_partida(self, resultado: Resultado) -> None:
        headers = {
            **self.headers,
            "Prefer": "resolution=ignore-duplicates,return=minimal",
        }
        try:
            resposta = requests.post(
                f"{self.base_url}/partidas",
                headers=headers,
                json=resultado.como_dict(),
                timeout=TIMEOUT,
            )
            resposta.raise_for_status()
        except requests.RequestException as exc:
            raise ErroDeConexao(f"A partida não foi salva: {exc}") from exc

    def buscar_ranking(self, jogo_id: int) -> list[dict[str, Any]]:
        resposta = self._request(
            "GET",
            "ranking_publico",
            params={
                "select": "posicao,apelido,valor_ganho,tempo_segundos,data_hora",
                "jogo_id": f"eq.{jogo_id}",
                "order": "posicao.asc",
                "limit": "10",
            },
        )
        return resposta.json()


def dinheiro(valor: int | float) -> str:
    return f"R$ {valor:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def duracao(segundos: int | float) -> str:
    total = max(0, round(float(segundos)))
    return f"{total // 60}min {total % 60:02d}s"


def solicitar_apelido() -> str:
    while True:
        apelido = input("Digite seu apelido: ").strip()
        if apelido:
            return apelido[:40]
        print("O apelido não pode ficar vazio. Tente novamente.")


def preparar_partida(perguntas: list[dict[str, Any]]) -> list[dict[str, Any]]:
    selecionadas: list[dict[str, Any]] = []
    for dificuldade in DIFICULDADES:
        grupo = [p for p in perguntas if p["dificuldade"] == dificuldade]
        if len(grupo) < 3:
            raise ValueError(
                f"São necessárias 3 perguntas {dificuldade}s, mas o banco retornou {len(grupo)}."
            )
        selecionadas.extend(random.sample(grupo, 3))
    return selecionadas


def exibir_pergunta(pergunta: dict[str, Any], numero: int) -> str:
    dificuldade = pergunta["dificuldade"].upper()
    print(f"\n{'=' * 66}")
    print(f"PERGUNTA {numero}/9 • {dificuldade} • vale {dinheiro(PREMIOS[numero - 1])}")
    print(f"{'=' * 66}")
    print(pergunta["enunciado"])
    for letra in ALTERNATIVAS:
        print(f"  {letra}) {pergunta[f'alternativa_{letra.lower()}']}")

    while True:
        resposta = input("Resposta [A/B/C/D] ou [S] para desistir: ").strip().upper()
        if resposta in (*ALTERNATIVAS, "S"):
            return resposta
        print("Entrada inválida. Digite A, B, C, D ou S.")


def jogar(api: SupabaseApi, jogo: dict[str, Any]) -> Resultado | None:
    apelido = solicitar_apelido()
    try:
        perguntas = preparar_partida(api.buscar_perguntas(jogo["id"]))
    except (ErroDeConexao, ValueError) as exc:
        print(f"\nNão foi possível iniciar: {exc}")
        return None

    acertos = 0
    valor = 0
    motivo = "concluida"
    inicio = time.perf_counter()

    for numero, pergunta in enumerate(perguntas, start=1):
        resposta = exibir_pergunta(pergunta, numero)
        if resposta == "S":
            motivo = "desistencia"
            break
        if resposta != pergunta["correta"]:
            motivo = "erro"
            print(f"\nResposta incorreta. A alternativa certa era {pergunta['correta']}.")
            break

        acertos += 1
        valor = PREMIOS[acertos - 1]
        print(f"Acertou! Prêmio atual: {dinheiro(valor)}")

    tempo_segundos = round(time.perf_counter() - inicio, 3)
    resultado = Resultado(
        id=str(uuid.uuid4()),
        jogo_id=jogo["id"],
        apelido=apelido,
        valor_ganho=valor,
        tempo_segundos=tempo_segundos,
        acertos=acertos,
        motivo_encerramento=motivo,
        data_hora=datetime.now(timezone.utc).isoformat(),
    )

    print("\nRESULTADO")
    print(f"Jogador: {apelido}")
    print(f"Acertos: {acertos}/9")
    print(f"Prêmio fictício: {dinheiro(valor)}")
    print(f"Tempo: {duracao(tempo_segundos)}")
    return resultado


def tentar_salvar(api: SupabaseApi, resultado: Resultado) -> bool:
    try:
        api.salvar_partida(resultado)
        print("Partida salva no Supabase.")
        return True
    except ErroDeConexao as exc:
        print(f"Não foi possível salvar agora. {exc}")
        print("O resultado continuará disponível para uma nova tentativa nesta execução.")
        return False


def exibir_ranking(api: SupabaseApi, jogo_id: int) -> None:
    try:
        ranking = api.buscar_ranking(jogo_id)
    except ErroDeConexao as exc:
        print(f"Não foi possível consultar o ranking: {exc}")
        return

    print("\nTOP 10")
    if not ranking:
        print("Ainda não há partidas registradas.")
        return
    for item in ranking:
        print(
            f"{item['posicao']:>2}º  {item['apelido']:<20} "
            f"{dinheiro(float(item['valor_ganho'])):>17}  "
            f"{duracao(float(item['tempo_segundos'])):>10}"
        )


def carregar_configuracao() -> tuple[str, str, str]:
    load_dotenv()
    url = os.getenv("SUPABASE_URL", "").strip()
    secret = os.getenv("SUPABASE_SECRET_KEY", "").strip()
    nome_jogo = os.getenv("GAME_NAME", "Show do Milhão Tech").strip()
    if not url or not secret:
        raise SystemExit(
            "Configuração ausente. Copie .env.example para .env e preencha "
            "SUPABASE_URL e SUPABASE_SECRET_KEY."
        )
    return url, secret, nome_jogo


def main() -> None:
    url, secret, nome_jogo = carregar_configuracao()
    api = SupabaseApi(url, secret)
    try:
        jogo = api.buscar_jogo(nome_jogo)
    except ErroDeConexao as exc:
        raise SystemExit(str(exc)) from exc

    pendentes: dict[str, Resultado] = {}
    while True:
        print("\nSHOW DO MILHÃO TECH")
        print("1. Iniciar partida")
        print("2. Consultar ranking")
        print(f"3. Reenviar resultados pendentes ({len(pendentes)})")
        print("4. Sair")
        opcao = input("Escolha: ").strip()

        if opcao == "1":
            resultado = jogar(api, jogo)
            if resultado and not tentar_salvar(api, resultado):
                pendentes[resultado.id] = resultado
        elif opcao == "2":
            exibir_ranking(api, jogo["id"])
        elif opcao == "3":
            if not pendentes:
                print("Não há resultados pendentes.")
                continue
            for partida_id, resultado in list(pendentes.items()):
                if tentar_salvar(api, resultado):
                    del pendentes[partida_id]
        elif opcao == "4":
            if pendentes:
                print("Atenção: existem resultados não enviados nesta execução.")
            print("Até a próxima!")
            break
        else:
            print("Opção inválida. Digite 1, 2, 3 ou 4.")


if __name__ == "__main__":
    main()


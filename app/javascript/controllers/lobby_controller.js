import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["gamesList"]

  connect() {
    this.subscribeToLobby()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribeToLobby() {
    this.subscription = consumer.subscriptions.create("LobbyChannel", {
      received: (data) => this.handleMessage(data)
    })
  }

  handleMessage(data) {
    switch (data.type) {
      case "game_created":
        this.addGame(data.game)
        break
      case "game_started":
        this.removeGame(data.game_id)
        break
    }
  }

  addGame(game) {
    if (!this.hasGamesListTarget) return

    const noGames = this.gamesListTarget.querySelector(".no-games")
    if (noGames) noGames.remove()

    const gameHtml = `
      <div class="game-item" data-game-id="${game.id}">
        <div class="game-info">
          <span class="game-type-badge">${game.game_type_name}</span>
          <span class="game-host">Хост: ${game.player1.username}</span>
        </div>
        <a href="/games/${game.id}/join" data-method="post" class="btn btn-primary">Присоединиться</a>
      </div>
    `
    this.gamesListTarget.insertAdjacentHTML("beforeend", gameHtml)
  }

  removeGame(gameId) {
    const gameElement = this.gamesListTarget.querySelector(`[data-game-id="${gameId}"]`)
    if (gameElement) {
      gameElement.remove()
    }

    if (this.gamesListTarget.children.length === 0) {
      this.gamesListTarget.innerHTML = '<p class="no-games">Нет ожидающих игр. Создайте свою!</p>'
    }
  }
}

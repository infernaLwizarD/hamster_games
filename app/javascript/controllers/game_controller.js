import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["board", "status", "moves", "ticTacToeBoard", "rpslsBoard", "battleshipBoard", "shipSelector"]

  connect() {
    this.gameId = this.element.dataset.gameId
    this.gameType = this.element.dataset.gameType
    this.playerId = parseInt(this.element.dataset.playerId)
    this.currentTurnId = parseInt(this.element.dataset.currentTurnId)
    this.selectedShip = null
    this.shipHorizontal = true

    this.subscribeToGame()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribeToGame() {
    this.subscription = consumer.subscriptions.create(
      { channel: "GameChannel", game_id: this.gameId },
      {
        received: (data) => this.handleMessage(data)
      }
    )
  }

  handleMessage(data) {
    switch (data.type) {
      case "game_started":
        this.refreshPage()
        break
      case "move_made":
        this.updateGame(data.game)
        this.addMove(data.move)
        break
      case "game_finished":
        this.updateGame(data.game)
        this.showResult(data)
        break
      case "error":
        this.showError(data.message)
        break
    }
  }

  updateGame(gameState) {
    this.currentTurnId = gameState.current_turn_id
    this.refreshPage()
  }

  addMove(move) {
    if (this.hasMovesTarget) {
      const list = this.movesTarget.querySelector(".moves-list")
      if (list) {
        const li = document.createElement("li")
        li.textContent = move.description
        list.appendChild(li)
      }
    }
  }

  showResult(data) {
    setTimeout(() => this.refreshPage(), 500)
  }

  showError(message) {
    alert(message)
  }

  refreshPage() {
    window.location.reload()
  }

  // Tic Tac Toe
  async makeTicTacToeMove(event) {
    const position = event.currentTarget.dataset.position
    await this.sendMove({ position: position })
  }

  // RPSLS
  async makeRpslsMove(event) {
    const choice = event.currentTarget.dataset.choice
    await this.sendMove({ choice: choice })
  }

  // Battleship
  selectShip(event) {
    this.selectedShip = event.currentTarget.dataset.shipType
    this.selectedShipLength = parseInt(event.currentTarget.dataset.shipLength)
    
    document.querySelectorAll(".ship-btn").forEach(btn => btn.classList.remove("selected"))
    event.currentTarget.classList.add("selected")
  }

  rotateShip() {
    this.shipHorizontal = !this.shipHorizontal
    const btn = event.currentTarget
    btn.textContent = this.shipHorizontal ? "Повернуть (H)" : "Повернуть (V)"
  }

  async placeShipCell(event) {
    if (!this.selectedShip) {
      alert("Сначала выберите корабль")
      return
    }

    const row = parseInt(event.currentTarget.dataset.row)
    const col = parseInt(event.currentTarget.dataset.col)

    await this.sendMove({
      action: "place_ship",
      ship_type: this.selectedShip,
      row: row,
      col: col,
      horizontal: this.shipHorizontal
    })

    this.selectedShip = null
  }

  async markReady() {
    await this.sendMove({ action: "ready" })
  }

  async shootCell(event) {
    const cell = event.currentTarget
    if (cell.classList.contains("hit") || cell.classList.contains("miss")) {
      return
    }

    const row = parseInt(cell.dataset.row)
    const col = parseInt(cell.dataset.col)

    await this.sendMove({
      action: "shoot",
      row: row,
      col: col
    })
  }

  async sendMove(moveData) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(`/games/${this.gameId}/move`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({ move_data: moveData })
      })

      if (!response.ok) {
        const data = await response.json()
        this.showError(data.error || "Ошибка при выполнении хода")
      }
    } catch (error) {
      console.error("Move error:", error)
      this.showError("Ошибка соединения")
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["board", "status", "moves", "ticTacToeBoard", "rpslsBoard", "battleshipBoard", "shipSelector", "rulesModal"]

  connect() {
    this.gameId = this.element.dataset.gameId
    this.gameType = this.element.dataset.gameType
    this.playerId = parseInt(this.element.dataset.playerId)
    this.currentTurnId = parseInt(this.element.dataset.currentTurnId)
    this.selectedShip = null
    this.shipHorizontal = true

    this.subscribeToGame()
  }

  showRules() {
    if (this.hasRulesModalTarget) {
      this.rulesModalTarget.classList.add('active')
    }
  }

  closeRules() {
    if (this.hasRulesModalTarget) {
      this.rulesModalTarget.classList.remove('active')
    }
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

  // Battleship - Drag and Drop
  dragStart(event) {
    const ship = event.currentTarget
    this.draggedShip = {
      type: ship.dataset.shipType,
      length: parseInt(ship.dataset.shipLength),
      horizontal: ship.dataset.horizontal === 'true',
      element: ship
    }
    ship.classList.add('dragging')
  }

  dragEnd(event) {
    event.currentTarget.classList.remove('dragging')
    this.draggedShip = null
  }

  rotateShipDock(event) {
    const ship = event.currentTarget
    const isHorizontal = ship.dataset.horizontal === 'true'
    ship.dataset.horizontal = (!isHorizontal).toString()
    
    const visual = ship.querySelector('.ship-visual')
    visual.classList.toggle('vertical', !isHorizontal)
    visual.classList.toggle('horizontal', isHorizontal)
  }

  async placeShipCell(event) {
    event.preventDefault()
    
    if (!this.draggedShip) {
      return
    }

    const row = parseInt(event.currentTarget.dataset.row)
    const col = parseInt(event.currentTarget.dataset.col)

    const result = await this.sendMove({
      action: "place_ship",
      ship_type: this.draggedShip.type,
      row: row,
      col: col,
      horizontal: this.draggedShip.horizontal
    })

    // Mark ship as placed if successful
    if (result && this.draggedShip.element) {
      this.draggedShip.element.classList.add('placed')
      this.draggedShip.element.draggable = false
    }
  }

  allowDrop(event) {
    event.preventDefault()
    const cell = event.currentTarget
    
    if (this.draggedShip) {
      cell.classList.add('drop-target')
    }
  }

  removeDrop(event) {
    event.currentTarget.classList.remove('drop-target')
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
        return false
      }
      return true
    } catch (error) {
      console.error("Move error:", error)
      this.showError("Ошибка соединения")
      return false
    }
  }
}

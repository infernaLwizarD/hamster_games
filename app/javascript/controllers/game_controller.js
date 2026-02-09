import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["board", "status", "moves", "ticTacToeBoard", "rpslsBoard", "battleshipBoard", "fleetList", "rotateBtn", "rulesModal"]

  connect() {
    this.gameId = this.element.dataset.gameId
    this.gameType = this.element.dataset.gameType
    this.playerId = parseInt(this.element.dataset.playerId)
    this.currentTurnId = parseInt(this.element.dataset.currentTurnId)

    // Battleship placement state
    this.selectedShipType = null
    this.selectedShipLength = 0
    this.shipHorizontal = true
    this.hoveredCells = []
    this.movingShipType = null
    this.movingShipLength = 0
    this._dragShipLength = null
    this._dragShipType = null
    this._dragSource = null

    this.subscribeToGame()
    this.initBattleship()
  }

  initBattleship() {
    if (!this.hasBattleshipBoardTarget) return
    const boardEl = this.battleshipBoardTarget
    if (boardEl.dataset.phase !== 'placement') return
    if (boardEl.dataset.myReady === 'true') return

    // Auto-select first unplaced ship
    const firstUnplaced = this.element.querySelector('.bs-fleet-ship:not(.placed)')
    if (firstUnplaced) {
      this.doSelectShip(firstUnplaced)
    }
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
        window.location.reload()
        break
      case "turbo_stream":
        this.handleTurboStream(data.html)
        break
      case "add_move":
        this.addMove(data.html)
        break
      case "error":
        this.showError(data.message)
        break
    }
  }

  handleTurboStream(html) {
    Turbo.renderStreamMessage(html)

    const container = this.element
    this.currentTurnId = parseInt(container.dataset.currentTurnId)

    // Re-init battleship state after DOM replacement
    this.hoveredCells = []
    this.movingShipType = null
    this.movingShipLength = 0
    this._dragShipLength = null
    this._dragShipType = null
    this._dragSource = null
    this.initBattleship()
  }

  addMove(html) {
    if (this.hasMovesTarget) {
      const list = this.movesTarget.querySelector(".moves-list")
      if (list) {
        list.insertAdjacentHTML('beforeend', html)
        list.scrollTop = list.scrollHeight
      }
    }
  }

  showError(message) {
    alert(message)
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

  // ===== Battleship — Ship Placement =====

  // --- Fleet panel: select ship ---
  selectShip(event) {
    const btn = event.currentTarget
    if (btn.classList.contains('placed')) return
    this.doSelectShip(btn.dataset.shipType, parseInt(btn.dataset.shipLength))
  }

  doSelectShip(shipType, shipLength) {
    this.element.querySelectorAll('.bs-fleet-ship').forEach(el => el.classList.remove('active'))
    const btn = this.element.querySelector(`.bs-fleet-ship[data-ship-type="${shipType}"]`)
    if (btn) btn.classList.add('active')
    // Deselect any board-selected ship
    this.element.querySelectorAll('.bs-cell.bs-selected').forEach(el => el.classList.remove('bs-selected'))
    this.selectedShipType = shipType
    this.selectedShipLength = shipLength
    this.movingShipType = null
  }

  toggleOrientation() {
    this.shipHorizontal = !this.shipHorizontal
    if (this.hasRotateBtnTarget) {
      this.rotateBtnTarget.textContent = this.shipHorizontal ? '↔ Горизонт.' : '↕ Вертикал.'
    }
    this.clearHover()
  }

  // --- Board cell: hover preview ---
  placementHover(event) {
    const activeType = this.movingShipType || this.selectedShipType
    if (!activeType) return
    const length = this.movingShipType ? this.movingShipLength : this.selectedShipLength
    if (!length) return
    const cell = event.currentTarget
    const row = parseInt(cell.dataset.row)
    const col = parseInt(cell.dataset.col)
    this.showPreview(row, col, length)
  }

  placementLeave() {
    this.clearHover()
  }

  showPreview(row, col, length) {
    this.clearHover()
    if (!length) return

    const positions = this.calcPositions(row, col, length, this.shipHorizontal)
    const valid = positions.every(([r, c]) => r >= 0 && r < 10 && c >= 0 && c < 10)

    const board = this.element.querySelector('.bs-my-board tbody')
    if (!board) return

    positions.forEach(([r, c]) => {
      if (r < 0 || r >= 10 || c < 0 || c >= 10) return
      const td = board.rows[r]?.cells[c + 1]
      if (td) {
        td.classList.add(valid ? 'bs-preview' : 'bs-preview-invalid')
        this.hoveredCells.push(td)
      }
    })
  }

  clearHover() {
    this.hoveredCells.forEach(td => {
      td.classList.remove('bs-preview', 'bs-preview-invalid')
    })
    this.hoveredCells = []
  }

  calcPositions(row, col, length, horizontal) {
    const positions = []
    for (let i = 0; i < length; i++) {
      if (horizontal) {
        positions.push([row, col + i])
      } else {
        positions.push([row + i, col])
      }
    }
    return positions
  }

  // --- Board cell: click ---
  // Left click on ship cell = select for moving; left click on empty = place/move
  // Double click on ship cell = rotate
  async placementClick(event) {
    const cell = event.currentTarget
    const row = parseInt(cell.dataset.row)
    const col = parseInt(cell.dataset.col)
    const shipType = cell.dataset.shipType

    // Clicked on existing ship — select it for moving
    if (shipType) {
      if (this.movingShipType === shipType) {
        // Already selected — deselect
        this.cancelMoving()
        return
      }
      this.startMoving(shipType)
      return
    }

    // Clicked on empty cell — place or move ship
    if (this.movingShipType) {
      // Moving an existing ship to new position
      await this.sendMove({
        action: "place_ship",
        ship_type: this.movingShipType,
        row: row,
        col: col,
        horizontal: this.shipHorizontal
      })
      this.movingShipType = null
      this.movingShipLength = 0
      return
    }

    if (this.selectedShipType) {
      await this.sendMove({
        action: "place_ship",
        ship_type: this.selectedShipType,
        row: row,
        col: col,
        horizontal: this.shipHorizontal
      })
    }
  }

  // Double click on ship = rotate
  async placementDblClick(event) {
    const cell = event.currentTarget
    const shipType = cell.dataset.shipType
    if (!shipType) return

    await this.sendMove({
      action: "rotate_ship",
      ship_type: shipType
    })
  }

  // Right click on ship = remove
  async placementContext(event) {
    const cell = event.currentTarget
    const shipType = cell.dataset.shipType
    if (!shipType) return

    event.preventDefault()
    await this.sendMove({
      action: "remove_ship",
      ship_type: shipType
    })
  }

  startMoving(shipType) {
    // Get ship length from SHIPS data
    const boardEl = this.battleshipBoardTarget
    const allShips = JSON.parse(boardEl.dataset.ships || '{}')
    const length = allShips[shipType]
    if (!length) return

    // Highlight ship cells on board
    this.element.querySelectorAll('.bs-cell.bs-selected').forEach(el => el.classList.remove('bs-selected'))
    this.element.querySelectorAll(`.bs-cell[data-ship-type="${shipType}"]`).forEach(el => {
      el.classList.add('bs-selected')
    })

    // Deselect fleet panel
    this.element.querySelectorAll('.bs-fleet-ship').forEach(el => el.classList.remove('active'))
    this.selectedShipType = null
    this.selectedShipLength = 0

    this.movingShipType = shipType
    this.movingShipLength = length
  }

  cancelMoving() {
    this.element.querySelectorAll('.bs-cell.bs-selected').forEach(el => el.classList.remove('bs-selected'))
    this.movingShipType = null
    this.movingShipLength = 0
  }

  // --- Drag and drop from fleet panel ---
  fleetDragStart(event) {
    const btn = event.currentTarget
    if (btn.classList.contains('placed')) {
      event.preventDefault()
      return
    }
    const shipType = btn.dataset.shipType
    const shipLength = btn.dataset.shipLength
    event.dataTransfer.setData('text/plain', JSON.stringify({
      shipType: shipType,
      shipLength: parseInt(shipLength),
      source: 'fleet'
    }))
    event.dataTransfer.effectAllowed = 'move'
    btn.classList.add('dragging')
  }

  fleetDragEnd(event) {
    event.currentTarget.classList.remove('dragging')
  }

  // --- Drag from board cell (move existing ship) ---
  boardDragStart(event) {
    const cell = event.currentTarget
    const shipType = cell.dataset.shipType
    if (!shipType) {
      event.preventDefault()
      return
    }
    const boardEl = this.battleshipBoardTarget
    const allShips = JSON.parse(boardEl.dataset.ships || '{}')
    const length = allShips[shipType]

    event.dataTransfer.setData('text/plain', JSON.stringify({
      shipType: shipType,
      shipLength: length,
      source: 'board'
    }))
    event.dataTransfer.effectAllowed = 'move'

    // Highlight dragged ship
    this.element.querySelectorAll(`.bs-cell[data-ship-type="${shipType}"]`).forEach(el => {
      el.classList.add('bs-dragging')
    })
  }

  boardDragEnd(event) {
    this.element.querySelectorAll('.bs-cell.bs-dragging').forEach(el => {
      el.classList.remove('bs-dragging')
    })
    this.clearHover()
  }

  // --- Board cell: drag over / drop ---
  cellDragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'

    let data
    try {
      // dataTransfer.getData not available in dragover in some browsers
      // Use stored drag info instead
    } catch(e) {}

    // Show preview based on stored drag state
    const cell = event.currentTarget
    const row = parseInt(cell.dataset.row)
    const col = parseInt(cell.dataset.col)

    if (this._dragShipLength) {
      this.showPreview(row, col, this._dragShipLength)
    }
  }

  cellDragEnter(event) {
    event.preventDefault()
    // Try to extract drag data for preview
    try {
      const raw = event.dataTransfer.types.includes('text/plain')
      if (raw && !this._dragShipLength) {
        // Can't read data in dragenter, store from dragstart via class
        const dragging = this.element.querySelector('.bs-fleet-ship.dragging')
        if (dragging) {
          this._dragShipLength = parseInt(dragging.dataset.shipLength)
          this._dragShipType = dragging.dataset.shipType
          this._dragSource = 'fleet'
        } else {
          const boardDragging = this.element.querySelector('.bs-cell.bs-dragging')
          if (boardDragging) {
            const boardEl = this.battleshipBoardTarget
            const allShips = JSON.parse(boardEl.dataset.ships || '{}')
            this._dragShipType = boardDragging.dataset.shipType
            this._dragShipLength = allShips[this._dragShipType]
            this._dragSource = 'board'
          }
        }
      }
    } catch(e) {}

    const cell = event.currentTarget
    const row = parseInt(cell.dataset.row)
    const col = parseInt(cell.dataset.col)
    if (this._dragShipLength) {
      this.showPreview(row, col, this._dragShipLength)
    }
  }

  cellDragLeave(event) {
    // Only clear if leaving the cell entirely
    const related = event.relatedTarget
    if (related && event.currentTarget.contains(related)) return
    this.clearHover()
  }

  async cellDrop(event) {
    event.preventDefault()
    this.clearHover()

    const cell = event.currentTarget
    const row = parseInt(cell.dataset.row)
    const col = parseInt(cell.dataset.col)

    let shipType, shipLength, source
    try {
      const data = JSON.parse(event.dataTransfer.getData('text/plain'))
      shipType = data.shipType
      shipLength = data.shipLength
      source = data.source
    } catch(e) {
      // Fallback to stored drag state
      shipType = this._dragShipType
      shipLength = this._dragShipLength
      source = this._dragSource
    }

    // Reset drag state
    this._dragShipLength = null
    this._dragShipType = null
    this._dragSource = null

    if (!shipType) return

    await this.sendMove({
      action: "place_ship",
      ship_type: shipType,
      row: row,
      col: col,
      horizontal: this.shipHorizontal
    })
  }

  // --- Action buttons ---
  async randomPlace() {
    await this.sendMove({ action: "random_place" })
  }

  async clearBoard() {
    await this.sendMove({ action: "clear_board" })
  }

  async markReady() {
    await this.sendMove({ action: "ready" })
  }

  // ===== Battleship — Battle Phase =====

  async shootCell(event) {
    const cell = event.currentTarget
    if (cell.classList.contains("bs-hit") || cell.classList.contains("bs-miss")) {
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

  // ===== Common =====

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

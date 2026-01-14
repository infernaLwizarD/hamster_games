import { Application } from "@hotwired/stimulus"
import GameController from "controllers/game_controller"
import LobbyController from "controllers/lobby_controller"

const application = Application.start()

application.register("game", GameController)
application.register("lobby", LobbyController)

application.debug = false
window.Stimulus = application

export { application }

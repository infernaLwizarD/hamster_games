class LobbyController < ApplicationController
  def index
    @games = Game.waiting.vs_humans.includes(:player1)
    @game_types = Game::GAME_TYPES
  end
end

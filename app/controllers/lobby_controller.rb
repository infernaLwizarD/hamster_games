class LobbyController < ApplicationController
  def index
    @games = Game.waiting.includes(:player1)
    @game_types = Game::GAME_TYPES
  end
end

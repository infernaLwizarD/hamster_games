class StatisticsController < ApplicationController
  def index
    @players = Player.order(wins_count: :desc).limit(20)
  end

  def show
    @player = Player.find(params[:id])
    @games = @player.games.finished.includes(:player1, :player2, :winner).order(finished_at: :desc).limit(50)
  end

  def game_history
    @game = Game.find(params[:id])
    @moves = @game.game_moves.includes(:player)
  end
end

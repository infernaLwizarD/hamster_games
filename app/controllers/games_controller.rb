class GamesController < ApplicationController
  before_action :set_game, only: [:show, :join, :move]

  def index
    @games = current_player.games.includes(:player1, :player2, :winner).order(created_at: :desc)
  end

  def show
    unless @game.player_role(current_player)
      redirect_to lobby_path, alert: 'Вы не участник этой игры'
      return
    end
  end

  def create
    @game = Game.new(game_params)
    @game.player1 = current_player
    @game.status = 'waiting'

    if @game.save
      GameService.for(@game).initialize_game
      ActionCable.server.broadcast('lobby', { type: 'game_created', game: game_info(@game) })
      redirect_to game_path(@game)
    else
      redirect_to lobby_path, alert: 'Не удалось создать игру'
    end
  end

  def join
    if @game.waiting? && @game.player1 != current_player
      @game.update!(player2: current_player)
      @game.start_game!

      ActionCable.server.broadcast('lobby', { type: 'game_started', game_id: @game.id })
      GameChannel.broadcast_to(@game, { type: 'game_started', game: game_state(@game) })

      redirect_to game_path(@game)
    else
      redirect_to lobby_path, alert: 'Не удалось присоединиться к игре'
    end
  end

  def move
    game_service = GameService.for(@game)
    result = game_service.make_move(current_player, move_params.to_h)

    if result[:success]
      GameChannel.broadcast_to(@game, {
        type: 'move_made',
        game: game_state(@game.reload),
        move: move_info(result[:move])
      })

      if @game.finished?
        GameChannel.broadcast_to(@game, {
          type: 'game_finished',
          game: game_state(@game),
          winner_id: @game.winner_id
        })
      end

      head :ok
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  private

  def set_game
    @game = Game.find(params[:id])
  end

  def game_params
    params.require(:game).permit(:game_type)
  end

  def move_params
    params.require(:move_data).permit(:position, :choice, :action, :ship_type, :row, :col, :horizontal)
  end

  def game_info(game)
    {
      id: game.id,
      game_type: game.game_type,
      game_type_name: game.game_type_name,
      player1: { id: game.player1.id, username: game.player1.username }
    }
  end

  def game_state(game)
    {
      id: game.id,
      status: game.status,
      state: game.state,
      current_turn_id: game.current_turn_id,
      winner_id: game.winner_id,
      player1: player_info(game.player1),
      player2: player_info(game.player2)
    }
  end

  def player_info(player)
    return nil unless player
    { id: player.id, username: player.username }
  end

  def move_info(move)
    {
      id: move.id,
      player_id: move.player_id,
      move_number: move.move_number,
      move_data: move.move_data,
      description: move.description
    }
  end
end

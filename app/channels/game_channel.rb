class GameChannel < ApplicationCable::Channel
  def subscribed
    @game = Game.find(params[:game_id])
    stream_for @game
  end

  def unsubscribed
    stop_all_streams
  end

  def make_move(data)
    return unless current_player && @game

    game_service = GameService.for(@game)
    result = game_service.make_move(current_player, data['move_data'])

    if result[:success]
      GameChannel.broadcast_to(@game, {
        type: 'move_made',
        game: game_state(@game.reload),
        move: result[:move]
      })

      if @game.finished?
        GameChannel.broadcast_to(@game, {
          type: 'game_finished',
          game: game_state(@game),
          winner_id: @game.winner_id
        })
      end
    else
      transmit({ type: 'error', message: result[:error] })
    end
  end

  private

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
end

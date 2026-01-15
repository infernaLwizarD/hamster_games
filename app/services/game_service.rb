class GameService
  def self.for(game)
    case game.game_type
    when 'tic_tac_toe'
      TicTacToeService.new(game)
    when 'rpsls'
      RpslsService.new(game)
    when 'battleship'
      BattleshipService.new(game)
    else
      raise "Unknown game type: #{game.game_type}"
    end
  end

  def initialize(game)
    @game = game
  end

  def make_move(player, move_data)
    raise NotImplementedError
  end

  def valid_move?(player, move_data)
    raise NotImplementedError
  end

  protected

  def create_move(player, move_data, description)
    @game.game_moves.create!(
      player: player,
      move_data: move_data,
      description: description
    )
  end

  def switch_turn
    if @game.vs_bot?
      next_player = @game.player1
    else
      next_player = @game.current_turn == @game.player1 ? @game.player2 : @game.player1
    end
    @game.update!(current_turn: next_player)
  end
end

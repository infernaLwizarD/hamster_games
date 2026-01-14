class TicTacToeService < GameService
  WINNING_COMBINATIONS = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6]
  ].freeze

  def initialize_game
    @game.update!(state: { 'board' => Array.new(9, nil) })
  end

  def make_move(player, move_data, bot: false)
    position = move_data['position'].to_i

    unless valid_move?(player, move_data, bot: bot)
      return { success: false, error: 'Недопустимый ход' }
    end

    board = @game.state['board'].dup
    is_player1 = bot ? false : (player == @game.player1)
    symbol = is_player1 ? 'X' : 'O'
    board[position] = symbol

    @game.update!(state: { 'board' => board })

    player_name = bot ? 'Бот' : player.username
    move = create_move(player, move_data, "#{player_name} поставил #{symbol} на позицию #{position + 1}")

    winner = bot ? nil : player
    if winner?(board, symbol)
      @game.finish_game!(winner)
    elsif board_full?(board)
      @game.finish_game!(nil)
    else
      switch_turn unless bot
    end

    { success: true, move: move }
  end

  def valid_move?(player, move_data, bot: false)
    return false unless @game.playing?
    return false if !bot && @game.current_turn_id != player&.id

    position = move_data['position'].to_i
    return false if position < 0 || position > 8

    board = @game.state['board']
    board[position].nil?
  end

  private

  def winner?(board, symbol)
    WINNING_COMBINATIONS.any? do |combo|
      combo.all? { |pos| board[pos] == symbol }
    end
  end

  def board_full?(board)
    board.none?(&:nil?)
  end
end

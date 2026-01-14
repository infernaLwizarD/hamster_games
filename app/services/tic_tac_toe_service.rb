class TicTacToeService < GameService
  WINNING_COMBINATIONS = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6]
  ].freeze

  def initialize_game
    @game.update!(state: { 'board' => Array.new(9, nil) })
  end

  def make_move(player, move_data)
    position = move_data['position'].to_i

    unless valid_move?(player, move_data)
      return { success: false, error: 'Недопустимый ход' }
    end

    board = @game.state['board'].dup
    symbol = player == @game.player1 ? 'X' : 'O'
    board[position] = symbol

    @game.update!(state: { 'board' => board })

    move = create_move(player, move_data, "#{player.username} поставил #{symbol} на позицию #{position + 1}")

    if winner?(board, symbol)
      @game.finish_game!(player)
    elsif board_full?(board)
      @game.finish_game!(nil)
    else
      switch_turn
    end

    { success: true, move: move }
  end

  def valid_move?(player, move_data)
    return false unless @game.playing?
    return false unless @game.current_turn_id == player.id

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

class TicTacToeBotService < BotService
  WINNING_COMBINATIONS = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6]
  ].freeze

  def make_move
    board = game.state['board']
    position = choose_position(board)
    { 'position' => position }
  end

  private

  def choose_position(board)
    if random_chance(easy: 0.7, medium: 0.4, hard: 0.1)
      random_move(board)
    else
      smart_move(board)
    end
  end

  def smart_move(board)
    winning_move(board, 'O') ||
      blocking_move(board, 'X') ||
      center_move(board) ||
      corner_move(board) ||
      random_move(board)
  end

  def winning_move(board, symbol)
    find_winning_position(board, symbol)
  end

  def blocking_move(board, symbol)
    find_winning_position(board, symbol)
  end

  def find_winning_position(board, symbol)
    WINNING_COMBINATIONS.each do |combo|
      values = combo.map { |i| board[i] }
      if values.count(symbol) == 2 && values.count(nil) == 1
        empty_index = combo.find { |i| board[i].nil? }
        return empty_index
      end
    end
    nil
  end

  def center_move(board)
    board[4].nil? ? 4 : nil
  end

  def corner_move(board)
    corners = [0, 2, 6, 8].shuffle
    corners.find { |i| board[i].nil? }
  end

  def random_move(board)
    available = board.each_index.select { |i| board[i].nil? }
    available.sample
  end
end

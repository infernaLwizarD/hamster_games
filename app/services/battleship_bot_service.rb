class BattleshipBotService < BotService
  BOARD_SIZE = 10
  SHIPS = {
    'carrier' => 5,
    'battleship' => 4,
    'cruiser' => 3,
    'submarine' => 3,
    'destroyer' => 2
  }.freeze

  def make_move
    phase = game.state['phase']

    case phase
    when 'placement'
      place_ships
    when 'battle'
      shoot
    end
  end

  def place_ships
    state = game.state
    ships_placed = state['player2_ships'] || {}

    SHIPS.each do |ship_type, length|
      next if ships_placed.key?(ship_type)

      position = find_valid_ship_position(state, length)
      return {
        'action' => 'place_ship',
        'ship_type' => ship_type,
        'row' => position[:row],
        'col' => position[:col],
        'horizontal' => position[:horizontal]
      }
    end

    { 'action' => 'ready' }
  end

  def shoot
    shots = game.state['player2_shots'] || Array.new(BOARD_SIZE) { Array.new(BOARD_SIZE, nil) }

    target = if random_chance(easy: 0.8, medium: 0.5, hard: 0.2)
               random_target(shots)
             else
               smart_target(shots)
             end

    {
      'action' => 'shoot',
      'row' => target[:row],
      'col' => target[:col]
    }
  end

  private

  def find_valid_ship_position(state, length)
    board = state['player2_board'] || Array.new(BOARD_SIZE) { Array.new(BOARD_SIZE, nil) }

    100.times do
      horizontal = [true, false].sample
      if horizontal
        row = rand(BOARD_SIZE)
        col = rand(BOARD_SIZE - length + 1)
      else
        row = rand(BOARD_SIZE - length + 1)
        col = rand(BOARD_SIZE)
      end

      positions = calculate_positions(row, col, length, horizontal)
      if positions.all? { |r, c| board[r][c].nil? }
        return { row: row, col: col, horizontal: horizontal }
      end
    end

    { row: 0, col: 0, horizontal: true }
  end

  def calculate_positions(start_row, start_col, length, horizontal)
    positions = []
    length.times do |i|
      if horizontal
        positions << [start_row, start_col + i]
      else
        positions << [start_row + i, start_col]
      end
    end
    positions
  end

  def smart_target(shots)
    hit_cells = find_hit_cells(shots)

    if hit_cells.any?
      adjacent = find_adjacent_targets(shots, hit_cells)
      return adjacent if adjacent
    end

    random_target(shots)
  end

  def find_hit_cells(shots)
    hits = []
    BOARD_SIZE.times do |row|
      BOARD_SIZE.times do |col|
        hits << [row, col] if shots[row][col] == 'hit'
      end
    end
    hits
  end

  def find_adjacent_targets(shots, hits)
    directions = [[-1, 0], [1, 0], [0, -1], [0, 1]]

    hits.each do |row, col|
      directions.shuffle.each do |dr, dc|
        new_row = row + dr
        new_col = col + dc

        next unless valid_position?(new_row, new_col)
        next unless shots[new_row][new_col].nil?

        return { row: new_row, col: new_col }
      end
    end

    nil
  end

  def random_target(shots)
    available = []
    BOARD_SIZE.times do |row|
      BOARD_SIZE.times do |col|
        available << { row: row, col: col } if shots[row][col].nil?
      end
    end

    if difficulty == 'hard'
      available.select { |t| (t[:row] + t[:col]).even? }.sample || available.sample
    else
      available.sample
    end
  end

  def valid_position?(row, col)
    row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE
  end
end

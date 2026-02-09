class BattleshipService < GameService
  BOARD_SIZE = 10
  COL_LABELS = %w[А Б В Г Д Е Ж З И К].freeze
  # Классические правила морского боя: 1x4, 2x3, 3x2, 4x1
  SHIPS = {
    'battleship' => 4,    # 1 четырёхпалубный
    'cruiser1' => 3,      # 2 трёхпалубных
    'cruiser2' => 3,
    'destroyer1' => 2,    # 3 двухпалубных
    'destroyer2' => 2,
    'destroyer3' => 2,
    'submarine1' => 1,    # 4 однопалубных
    'submarine2' => 1,
    'submarine3' => 1,
    'submarine4' => 1
  }.freeze

  def initialize_game
    @game.update!(state: {
      'player1_board' => empty_board,
      'player2_board' => empty_board,
      'player1_shots' => empty_board,
      'player2_shots' => empty_board,
      'player1_ships' => {},
      'player2_ships' => {},
      'player1_ready' => false,
      'player2_ready' => false,
      'phase' => 'placement'
    })
  end

  def make_move(player, move_data, bot: false)
    action = move_data['action']

    case action
    when 'place_ship'
      place_ship(player, move_data, bot: bot)
    when 'ready'
      mark_ready(player, bot: bot)
    when 'shoot'
      shoot(player, move_data, bot: bot)
    when 'clear_board'
      clear_board(player)
    when 'random_place'
      random_place(player)
    when 'rotate_ship'
      rotate_ship(player, move_data)
    when 'remove_ship'
      remove_ship(player, move_data)
    else
      { success: false, error: 'Неизвестное действие' }
    end
  end

  def valid_move?(player, move_data, bot: false)
    return false unless @game.playing?
    true
  end

  private

  def empty_board
    Array.new(BOARD_SIZE) { Array.new(BOARD_SIZE, nil) }
  end

  def place_ship(player, move_data, bot: false)
    state = @game.state.dup
    player_key = bot ? 'player2' : (player == @game.player1 ? 'player1' : 'player2')

    ship_type = move_data['ship_type']
    start_row = move_data['row'].to_i
    start_col = move_data['col'].to_i
    horizontal = move_data['horizontal']

    return { success: false, error: 'Неизвестный тип корабля' } unless SHIPS[ship_type]

    ship_length = SHIPS[ship_type]
    positions = calculate_positions(start_row, start_col, ship_length, horizontal)

    return { success: false, error: 'Корабль выходит за пределы поля' } unless valid_positions?(positions)

    board = state["#{player_key}_board"]
    ships = state["#{player_key}_ships"]
    
    # Удалить старую позицию корабля если он уже размещен (для перемещения)
    if ships[ship_type]
      ships[ship_type].each { |r, c| board[r][c] = nil }
    end
    
    # Проверить что позиция не занята другими кораблями
    return { success: false, error: 'Позиция занята' } if positions.any? { |r, c| board[r][c] }
    
    # Проверить что корабли не примыкают друг к другу
    return { success: false, error: 'Корабли не могут примыкать друг к другу' } if ships_adjacent?(positions, board)

    positions.each { |r, c| board[r][c] = ship_type }
    state["#{player_key}_ships"][ship_type] = positions
    state["#{player_key}_board"] = board

    @game.update!(state: state)

    player_name = bot ? 'Бот' : player.username
    move = create_move(player, move_data, "#{player_name} разместил #{ship_type}")
    { success: true, move: move }
  end

  def mark_ready(player, bot: false)
    state = @game.state.dup
    player_key = bot ? 'player2' : (player == @game.player1 ? 'player1' : 'player2')

    ships_placed = state["#{player_key}_ships"].keys
    return { success: false, error: 'Разместите все корабли' } unless ships_placed.sort == SHIPS.keys.sort

    state["#{player_key}_ready"] = true
    @game.update!(state: state)

    if state['player1_ready'] && state['player2_ready']
      state['phase'] = 'battle'
      @game.update!(state: state, current_turn: @game.player1)
    end

    player_name = bot ? 'Бот' : player.username
    move = create_move(player, { action: 'ready' }, "#{player_name} готов к бою")
    { success: true, move: move }
  end

  def shoot(player, move_data, bot: false)
    return { success: false, error: 'Не ваш ход' } if !bot && @game.current_turn_id != player&.id
    return { success: false, error: 'Игра не в фазе боя' } unless @game.state['phase'] == 'battle'

    state = @game.state.dup
    player_key = bot ? 'player2' : (player == @game.player1 ? 'player1' : 'player2')
    opponent_key = bot ? 'player1' : (player == @game.player1 ? 'player2' : 'player1')

    row = move_data['row'].to_i
    col = move_data['col'].to_i

    return { success: false, error: 'Выстрел за пределы поля' } unless valid_position?(row, col)

    shots = state["#{player_key}_shots"]
    return { success: false, error: 'Уже стреляли сюда' } if shots[row][col]

    opponent_board = state["#{opponent_key}_board"]
    hit = opponent_board[row][col].present?

    shots[row][col] = hit ? 'hit' : 'miss'
    state["#{player_key}_shots"] = shots

    player_name = bot ? 'Бот' : player.username
    result_text = hit ? 'попал' : 'промахнулся'
    move = create_move(player, move_data, "#{player_name} #{result_text} по #{COL_LABELS[col]}#{row + 1}")

    if hit
      ship_type = opponent_board[row][col]
      if ship_destroyed?(state, opponent_key, ship_type, shots)
        mark_surrounding_cells(state, opponent_key, player_key, ship_type)
        ship_display = ship_display_name(ship_type)
        move.update!(description: "#{player_name} потопил #{ship_display}!")
      end

      if all_ships_destroyed?(state, opponent_key, shots)
        @game.update!(state: state)
        if bot
          @game.finish_game!(nil, bot_won: true)
        else
          @game.finish_game!(player, bot_won: false)
        end
        return { success: true, move: move }
      end
    end

    @game.update!(state: state)
    switch_turn unless hit || bot

    { success: true, move: move }
  end

  def clear_board(player)
    state = @game.state.dup
    player_key = player == @game.player1 ? 'player1' : 'player2'

    return { success: false, error: 'Вы уже готовы' } if state["#{player_key}_ready"]

    state["#{player_key}_board"] = empty_board
    state["#{player_key}_ships"] = {}
    @game.update!(state: state)

    { success: true, move: nil }
  end

  def random_place(player)
    state = @game.state.dup
    player_key = player == @game.player1 ? 'player1' : 'player2'

    return { success: false, error: 'Вы уже готовы' } if state["#{player_key}_ready"]

    board = empty_board
    ships = {}

    SHIPS.each do |ship_type, length|
      placed = false
      200.times do
        horizontal = [true, false].sample
        if horizontal
          r = rand(BOARD_SIZE)
          c = rand(BOARD_SIZE - length + 1)
        else
          r = rand(BOARD_SIZE - length + 1)
          c = rand(BOARD_SIZE)
        end

        positions = calculate_positions(r, c, length, horizontal)
        next unless positions.all? { |pr, pc| board[pr][pc].nil? }
        next if ships_adjacent?(positions, board)

        positions.each { |pr, pc| board[pr][pc] = ship_type }
        ships[ship_type] = positions
        placed = true
        break
      end

      unless placed
        return { success: false, error: 'Не удалось разместить корабли, попробуйте ещё раз' }
      end
    end

    state["#{player_key}_board"] = board
    state["#{player_key}_ships"] = ships
    @game.update!(state: state)

    { success: true, move: nil }
  end

  def rotate_ship(player, move_data)
    state = @game.state.dup
    player_key = player == @game.player1 ? 'player1' : 'player2'

    return { success: false, error: 'Вы уже готовы' } if state["#{player_key}_ready"]

    ship_type = move_data['ship_type']
    ships = state["#{player_key}_ships"]
    positions = ships[ship_type]
    return { success: false, error: 'Корабль не найден' } unless positions&.any?

    length = SHIPS[ship_type]
    return { success: true, move: nil } if length == 1

    board = state["#{player_key}_board"]

    # Определяем текущую ориентацию
    rows = positions.map(&:first).uniq
    currently_horizontal = rows.size == 1

    # Начальная точка — первая клетка корабля
    start_row = positions.map(&:first).min
    start_col = positions.map(&:last).min

    # Новые позиции — меняем ориентацию
    new_positions = calculate_positions(start_row, start_col, length, !currently_horizontal)

    # Проверяем что новые позиции в пределах поля
    return { success: false, error: 'Корабль выходит за пределы поля' } unless valid_positions?(new_positions)

    # Убираем старый корабль с доски
    positions.each { |r, c| board[r][c] = nil }

    # Проверяем что новые позиции не заняты
    if new_positions.any? { |r, c| board[r][c] }
      positions.each { |r, c| board[r][c] = ship_type }
      return { success: false, error: 'Позиция занята' }
    end

    # Проверяем соседство
    if ships_adjacent?(new_positions, board)
      positions.each { |r, c| board[r][c] = ship_type }
      return { success: false, error: 'Корабли не могут примыкать друг к другу' }
    end

    # Размещаем корабль в новой ориентации
    new_positions.each { |r, c| board[r][c] = ship_type }
    ships[ship_type] = new_positions
    state["#{player_key}_board"] = board
    state["#{player_key}_ships"] = ships
    @game.update!(state: state)

    { success: true, move: nil }
  end

  def remove_ship(player, move_data)
    state = @game.state.dup
    player_key = player == @game.player1 ? 'player1' : 'player2'

    return { success: false, error: 'Вы уже готовы' } if state["#{player_key}_ready"]

    ship_type = move_data['ship_type']
    ships = state["#{player_key}_ships"]
    positions = ships[ship_type]
    return { success: false, error: 'Корабль не найден' } unless positions&.any?

    board = state["#{player_key}_board"]
    positions.each { |r, c| board[r][c] = nil }
    ships.delete(ship_type)

    state["#{player_key}_board"] = board
    state["#{player_key}_ships"] = ships
    @game.update!(state: state)

    { success: true, move: nil }
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

  def valid_positions?(positions)
    positions.all? { |r, c| valid_position?(r, c) }
  end

  def valid_position?(row, col)
    row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE
  end

  def ship_destroyed?(state, player_key, ship_type, shots)
    positions = state["#{player_key}_ships"][ship_type]
    return false unless positions

    positions.all? { |r, c| shots[r][c] == 'hit' }
  end

  def all_ships_destroyed?(state, player_key, shots)
    state["#{player_key}_ships"].all? do |ship_type, positions|
      positions.all? { |r, c| shots[r][c] == 'hit' }
    end
  end

  def mark_surrounding_cells(state, opponent_key, player_key, ship_type)
    positions = state["#{opponent_key}_ships"][ship_type]
    return unless positions

    shots = state["#{player_key}_shots"]
    positions.each do |row, col|
      [-1, 0, 1].each do |dr|
        [-1, 0, 1].each do |dc|
          next if dr == 0 && dc == 0
          nr, nc = row + dr, col + dc
          next unless valid_position?(nr, nc)
          shots[nr][nc] = 'miss' if shots[nr][nc].nil?
        end
      end
    end
    state["#{player_key}_shots"] = shots
  end

  def ship_display_name(ship_type)
    case ship_type
    when 'battleship' then 'Линкор'
    when /cruiser/ then 'Крейсер'
    when /destroyer/ then 'Эсминец'
    when /submarine/ then 'Подлодку'
    else ship_type
    end
  end

  def ships_adjacent?(positions, board)
    positions.each do |row, col|
      # Проверить все 8 направлений вокруг клетки
      [-1, 0, 1].each do |dr|
        [-1, 0, 1].each do |dc|
          next if dr == 0 && dc == 0 # Пропустить саму клетку
          
          check_row = row + dr
          check_col = col + dc
          
          # Проверить что клетка в пределах поля
          next unless valid_position?(check_row, check_col)
          
          # Если в соседней клетке есть корабль - это нарушение
          return true if board[check_row][check_col].present?
        end
      end
    end
    false
  end
end

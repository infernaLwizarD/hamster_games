class BattleshipService < GameService
  BOARD_SIZE = 10
  SHIPS = {
    'carrier' => 5,
    'battleship' => 4,
    'cruiser' => 3,
    'submarine' => 3,
    'destroyer' => 2
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
    move = create_move(player, move_data, "#{player_name} #{result_text} по #{('A'.ord + col).chr}#{row + 1}")

    if hit
      ship_type = opponent_board[row][col]
      if ship_destroyed?(state, opponent_key, ship_type, shots)
        move.update!(description: "#{player_name} потопил #{ship_type}!")
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

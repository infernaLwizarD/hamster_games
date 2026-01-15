class RpslsService < GameService
  CHOICES = %w[rock paper scissors lizard spock].freeze

  WINS = {
    'rock' => %w[scissors lizard],
    'paper' => %w[rock spock],
    'scissors' => %w[paper lizard],
    'lizard' => %w[paper spock],
    'spock' => %w[rock scissors]
  }.freeze

  CHOICE_NAMES = {
    'rock' => 'Камень',
    'paper' => 'Бумага',
    'scissors' => 'Ножницы',
    'lizard' => 'Ящерица',
    'spock' => 'Спок'
  }.freeze

  def initialize_game
    @game.update!(state: { 'player1_choice' => nil, 'player2_choice' => nil, 'round' => 1 })
  end

  def make_move(player, move_data, bot: false)
    choice = move_data['choice']

    unless valid_move?(player, move_data, bot: bot)
      return { success: false, error: 'Недопустимый выбор' }
    end

    state = @game.state.dup
    player_key = bot ? 'player2_choice' : (player == @game.player1 ? 'player1_choice' : 'player2_choice')
    state[player_key] = choice

    @game.update!(state: state)

    player_name = bot ? 'Бот' : player.username
    move = create_move(player, { choice: choice }, "#{player_name} выбрал #{CHOICE_NAMES[choice]}")

    if state['player1_choice'] && state['player2_choice']
      determine_winner(state)
    end

    { success: true, move: move }
  end

  def valid_move?(player, move_data, bot: false)
    return false unless @game.playing?

    choice = move_data['choice']
    return false unless CHOICES.include?(choice)

    player_key = bot ? 'player2_choice' : (player == @game.player1 ? 'player1_choice' : 'player2_choice')
    @game.state[player_key].nil?
  end

  private

  def determine_winner(state)
    p1_choice = state['player1_choice']
    p2_choice = state['player2_choice']

    if p1_choice == p2_choice
      @game.finish_game!(nil)
    elsif WINS[p1_choice].include?(p2_choice)
      @game.finish_game!(@game.player1)
    else
      winner = @game.vs_bot? ? nil : @game.player2
      @game.finish_game!(winner)
    end
  end
end

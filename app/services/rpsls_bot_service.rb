class RpslsBotService < BotService
  CHOICES = %w[rock paper scissors lizard spock].freeze

  WINS = {
    'rock' => %w[scissors lizard],
    'paper' => %w[rock spock],
    'scissors' => %w[paper lizard],
    'lizard' => %w[paper spock],
    'spock' => %w[rock scissors]
  }.freeze

  COUNTERS = {
    'rock' => %w[paper spock],
    'paper' => %w[scissors lizard],
    'scissors' => %w[rock spock],
    'lizard' => %w[rock scissors],
    'spock' => %w[paper lizard]
  }.freeze

  def make_move
    { 'choice' => choose_choice }
  end

  private

  def choose_choice
    player_history = analyze_player_history

    if player_history.empty? || random_chance(easy: 0.8, medium: 0.5, hard: 0.2)
      random_choice
    else
      counter_choice(player_history)
    end
  end

  def analyze_player_history
    game.player1.game_moves
        .joins(:game)
        .where(games: { game_type: 'rpsls' })
        .order(created_at: :desc)
        .limit(10)
        .pluck(:move_data)
        .map { |data| data['choice'] }
        .compact
  end

  def counter_choice(history)
    most_common = history.tally.max_by { |_, count| count }&.first
    return random_choice unless most_common

    counters = COUNTERS[most_common]
    counters.sample
  end

  def random_choice
    CHOICES.sample
  end
end

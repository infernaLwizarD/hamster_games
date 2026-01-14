class BotService
  attr_reader :game, :difficulty

  def initialize(game)
    @game = game
    @difficulty = game.bot_difficulty
  end

  def self.for(game)
    case game.game_type
    when 'tic_tac_toe'
      TicTacToeBotService.new(game)
    when 'rpsls'
      RpslsBotService.new(game)
    when 'battleship'
      BattleshipBotService.new(game)
    else
      raise "Unknown game type: #{game.game_type}"
    end
  end

  def make_move
    raise NotImplementedError
  end

  protected

  def random_chance(easy:, medium:, hard:)
    chance = case difficulty
             when 'easy' then easy
             when 'medium' then medium
             when 'hard' then hard
             else medium
             end
    rand < chance
  end
end

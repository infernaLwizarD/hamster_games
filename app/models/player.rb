class Player < ApplicationRecord
  has_secure_password

  has_many :games_as_player1, class_name: 'Game', foreign_key: 'player1_id', dependent: :destroy
  has_many :games_as_player2, class_name: 'Game', foreign_key: 'player2_id', dependent: :nullify
  has_many :won_games, class_name: 'Game', foreign_key: 'winner_id', dependent: :nullify
  has_many :game_moves, dependent: :destroy

  validates :username, presence: true, uniqueness: true, length: { minimum: 3, maximum: 20 }
  validates :password, presence: true, length: { minimum: 6 }, on: :create

  def games
    Game.where('player1_id = ? OR player2_id = ?', id, id)
  end

  def total_games
    wins_count + losses_count + draws_count
  end

  def win_rate
    return 0 if total_games.zero?
    (wins_count.to_f / total_games * 100).round(1)
  end
end

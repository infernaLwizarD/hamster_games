class Game < ApplicationRecord
  GAME_TYPES = %w[tic_tac_toe rpsls battleship].freeze
  STATUSES = %w[waiting playing finished].freeze

  belongs_to :player1, class_name: 'Player'
  belongs_to :player2, class_name: 'Player', optional: true
  belongs_to :winner, class_name: 'Player', optional: true
  belongs_to :current_turn, class_name: 'Player', optional: true
  has_many :game_moves, dependent: :destroy

  validates :game_type, presence: true, inclusion: { in: GAME_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :waiting, -> { where(status: 'waiting') }
  scope :playing, -> { where(status: 'playing') }
  scope :finished, -> { where(status: 'finished') }
  scope :by_type, ->(type) { where(game_type: type) }

  def game_type_name
    case game_type
    when 'tic_tac_toe' then 'Крестики-нолики'
    when 'rpsls' then 'Камень-ножницы-бумага-ящерица-Спок'
    when 'battleship' then 'Морской бой'
    else game_type
    end
  end

  def waiting?
    status == 'waiting'
  end

  def playing?
    status == 'playing'
  end

  def finished?
    status == 'finished'
  end

  def player_role(player)
    return :player1 if player1_id == player.id
    return :player2 if player2_id == player.id
    nil
  end

  def opponent(player)
    return player2 if player1_id == player.id
    return player1 if player2_id == player.id
    nil
  end

  def draw?
    finished? && winner_id.nil?
  end

  def start_game!
    return unless waiting? && player2.present?

    update!(
      status: 'playing',
      started_at: Time.current,
      current_turn: player1
    )
  end

  def finish_game!(winner_player = nil)
    transaction do
      update!(
        status: 'finished',
        finished_at: Time.current,
        winner: winner_player
      )

      if winner_player
        winner_player.increment!(:wins_count)
        loser = opponent(winner_player)
        loser&.increment!(:losses_count)
      else
        player1.increment!(:draws_count)
        player2&.increment!(:draws_count)
      end
    end
  end
end

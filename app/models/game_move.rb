class GameMove < ApplicationRecord
  belongs_to :game
  belongs_to :player

  validates :move_number, presence: true, numericality: { greater_than: 0 }

  default_scope { order(move_number: :asc) }

  before_validation :set_move_number, on: :create

  private

  def set_move_number
    self.move_number ||= (game.game_moves.maximum(:move_number) || 0) + 1
  end
end

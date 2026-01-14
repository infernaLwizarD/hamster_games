class AddBotDifficultyToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :bot_difficulty, :string
    add_index :games, :bot_difficulty
  end
end

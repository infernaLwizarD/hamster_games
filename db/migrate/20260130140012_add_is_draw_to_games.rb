class AddIsDrawToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :is_draw, :boolean, default: false
  end
end

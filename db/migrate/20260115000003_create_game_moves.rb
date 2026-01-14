class CreateGameMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :game_moves do |t|
      t.references :game, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: true
      t.integer :move_number, null: false
      t.jsonb :move_data, default: {}
      t.string :description

      t.timestamps
    end

    add_index :game_moves, [:game_id, :move_number]
  end
end

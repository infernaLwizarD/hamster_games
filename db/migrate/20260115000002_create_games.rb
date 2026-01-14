class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :game_type, null: false
      t.string :status, default: 'waiting'
      t.references :player1, null: false, foreign_key: { to_table: :players }
      t.references :player2, foreign_key: { to_table: :players }
      t.references :winner, foreign_key: { to_table: :players }
      t.references :current_turn, foreign_key: { to_table: :players }
      t.jsonb :state, default: {}
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :games, :game_type
    add_index :games, :status
  end
end

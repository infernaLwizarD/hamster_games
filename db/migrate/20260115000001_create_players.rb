class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :username, null: false
      t.string :password_digest, null: false
      t.integer :wins_count, default: 0
      t.integer :losses_count, default: 0
      t.integer :draws_count, default: 0

      t.timestamps
    end

    add_index :players, :username, unique: true
  end
end

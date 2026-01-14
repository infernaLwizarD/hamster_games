# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_15_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "game_moves", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.bigint "game_id", null: false
    t.jsonb "move_data", default: {}
    t.integer "move_number", null: false
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "move_number"], name: "index_game_moves_on_game_id_and_move_number"
    t.index ["game_id"], name: "index_game_moves_on_game_id"
    t.index ["player_id"], name: "index_game_moves_on_player_id"
  end

  create_table "games", force: :cascade do |t|
    t.string "bot_difficulty"
    t.datetime "created_at", null: false
    t.bigint "current_turn_id"
    t.datetime "finished_at"
    t.string "game_type", null: false
    t.bigint "player1_id", null: false
    t.bigint "player2_id"
    t.datetime "started_at"
    t.jsonb "state", default: {}
    t.string "status", default: "waiting"
    t.datetime "updated_at", null: false
    t.bigint "winner_id"
    t.index ["bot_difficulty"], name: "index_games_on_bot_difficulty"
    t.index ["current_turn_id"], name: "index_games_on_current_turn_id"
    t.index ["game_type"], name: "index_games_on_game_type"
    t.index ["player1_id"], name: "index_games_on_player1_id"
    t.index ["player2_id"], name: "index_games_on_player2_id"
    t.index ["status"], name: "index_games_on_status"
    t.index ["winner_id"], name: "index_games_on_winner_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "draws_count", default: 0
    t.integer "losses_count", default: 0
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "username", null: false
    t.integer "wins_count", default: 0
    t.index ["username"], name: "index_players_on_username", unique: true
  end

  add_foreign_key "game_moves", "games"
  add_foreign_key "game_moves", "players"
  add_foreign_key "games", "players", column: "current_turn_id"
  add_foreign_key "games", "players", column: "player1_id"
  add_foreign_key "games", "players", column: "player2_id"
  add_foreign_key "games", "players", column: "winner_id"
end

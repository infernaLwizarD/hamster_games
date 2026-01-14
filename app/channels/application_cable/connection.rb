module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_player

    def connect
      self.current_player = find_verified_player
    end

    private

    def find_verified_player
      if (player_id = cookies.signed[:player_id])
        Player.find_by(id: player_id)
      end
    end
  end
end

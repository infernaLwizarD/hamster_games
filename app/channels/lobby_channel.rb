class LobbyChannel < ApplicationCable::Channel
  def subscribed
    stream_from "lobby"
  end

  def unsubscribed
    stop_all_streams
  end
end

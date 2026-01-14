class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_login

  helper_method :current_player, :logged_in?

  private

  def current_player
    @current_player ||= Player.find_by(id: session[:player_id]) if session[:player_id]
  end

  def logged_in?
    current_player.present?
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: 'Пожалуйста, войдите в систему'
    end
  end

  def login(player)
    session[:player_id] = player.id
    cookies.signed[:player_id] = player.id
  end

  def logout
    session.delete(:player_id)
    cookies.delete(:player_id)
    @current_player = nil
  end
end

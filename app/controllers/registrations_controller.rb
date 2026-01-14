class RegistrationsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to lobby_path if logged_in?
    @player = Player.new
  end

  def create
    @player = Player.new(player_params)

    if @player.save
      login(@player)
      redirect_to lobby_path, notice: 'Регистрация успешна!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def player_params
    params.require(:player).permit(:username, :password, :password_confirmation)
  end
end

class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to lobby_path if logged_in?
  end

  def create
    player = Player.find_by(username: params[:username])

    if player&.authenticate(params[:password])
      login(player)
      redirect_to lobby_path, notice: 'Вы успешно вошли!'
    else
      flash.now[:alert] = 'Неверное имя пользователя или пароль'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to login_path, notice: 'Вы вышли из системы'
  end
end

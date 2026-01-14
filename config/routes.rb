Rails.application.routes.draw do
  # Authentication
  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#create'
  delete 'logout', to: 'sessions#destroy'

  get 'register', to: 'registrations#new'
  post 'register', to: 'registrations#create'

  # Lobby
  get 'lobby', to: 'lobby#index'

  # Games
  resources :games, only: [:index, :show, :create] do
    member do
      post :join
      post :move
    end
  end

  # Statistics
  get 'statistics', to: 'statistics#index'
  get 'statistics/:id', to: 'statistics#show', as: :player_statistics
  get 'games/:id/history', to: 'statistics#game_history', as: :game_history

  # Health check
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Root
  root 'lobby#index'
end

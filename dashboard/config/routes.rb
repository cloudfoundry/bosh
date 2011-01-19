Dashboard::Application.routes.draw do
  root :to => "homepage#index"

  match "login"  => "sessions#new",   :via => :get
  match "login"  => "sessions#login", :via => :post
  match "logout" => "sessions#logout", :via => :get

  resources :stemcells,   :only => :index
  resources :releases,    :only => :index
  resources :deployments, :only => :index
  resources :tasks, :only => :show do
    collection do
      get "running"
      get "recent"
    end
  end
end

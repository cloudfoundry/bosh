Dashboard::Application.routes.draw do
  root :to => "homepage#index"

  match "login"  => "sessions#new",   :via => :get
  match "login"  => "sessions#login", :via => :post
  match "logout" => "sessions#logout", :via => :get

  match "/running_tasks" => "tasks#running", :via => :get
  match "/recent_tasks"  => "tasks#recent",  :via => :get  

  resources :stemcells,   :only => :index
  resources :releases,    :only => :index
  resources :deployments, :only => :index
end

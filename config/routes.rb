Rails.application.routes.draw do
  resources :job_status_histories
  resources :reports
  resources :notifications
  resources :jobs
  mount EpiCas::Engine, at: "/"
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "pages#home"
end

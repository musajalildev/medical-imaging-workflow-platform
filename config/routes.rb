Rails.application.routes.draw do
  
  resources :complete_jobs
  resources :cancelled_jobs
  resources :image_files
  resources :job_status_histories
  resources :reports
  resources :notifications
  resources :jobs
  mount EpiCas::Engine, at: "/"
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :users, only: [:index, :edit, :update]
  # Defines the root path route ("/")
  root "pages#home"
end

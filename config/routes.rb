Rails.application.routes.draw do
    if Rails.env.development?
      namespace :dev do
        resource :session, only: [:new, :create, :destroy]
      end
    end

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
  resources :jobs, only: [:new, :create]
  # Defines the root path route ("/")
  root "pages#home"
end

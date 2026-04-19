Rails.application.routes.draw do
    if Rails.env.development?
      namespace :dev do
        resource :session, only: [:new, :create, :destroy]
      end
    end

  resources :image_files
  resources :job_status_histories
  resources :jobs do
    member do
      patch :update_status
      patch :complete_job
      patch :cancel_job
      patch :self_assign
    end
  end
  resources :reports
  resources :notifications
  mount EpiCas::Engine, at: "/"
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "pages#home"
end

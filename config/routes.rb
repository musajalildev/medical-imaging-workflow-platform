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
  resources :jobs do
    post :upload_output, on: :member
    get :update_status, on: :member
    patch :complete_update_status, on: :member

  end
  post '/files/upload', to: 'files#upload'
  get '/files/:file_id/download', to: 'files#download', as: :download_file
  delete '/files/:image_file_id/remove', to: 'files#remove', as: :remove_file
  mount EpiCas::Engine, at: "/"
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  root "pages#home"
end

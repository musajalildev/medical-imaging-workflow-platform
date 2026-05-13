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
  resources :jobs do
    member do
      patch :update_status
      patch :complete_job
      patch :cancel_job
      patch :self_assign
      patch :submit_draft
      patch :unassign
      patch :re_assign
      patch :uncancel_job
    end
  end
  resources :reports
  resources :notifications
  resources :jobs do
    post :upload_output, on: :member
  end
  post '/files/upload', to: 'files#upload'
  get '/files/:file_id/download', to: 'files#download', as: :download_file
  delete '/files/:image_file_id/remove', to: 'files#remove', as: :remove_file
  mount EpiCas::Engine, at: "/"
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :users, only: [:index, :edit, :update]

  get '/landing', to: 'pages#landing'
  get '/sign_up', to: 'pages#sign_up'
  post "send_sign_up_email", to: "pages#send_sign_up_email", as: :send_sign_up_email

  # Defines the root path route ("/")
  root "pages#landing"
end

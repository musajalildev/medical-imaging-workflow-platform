class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  # Disabling caching will prevent sensitive information being stored in the
  # browser cache. If your app does not deal with sensitive information then it
  # may be worth enabling caching for performance.
  before_action :dev_auto_login
  before_action :authenticate_user!
  before_action :update_headers_to_disable_caching

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html do
        redirect_to root_path, alert: "You are not authorized to access this page."
      end

      format.json do
        render json: { error: "Access denied" }, status: :forbidden
      end
    end
  end


  private
     def dev_auto_login
       return unless Rails.env.development?
       if (user_id = session[:dev_user_id])
         user = User.find_by(id: user_id)
         sign_in(user, store: false) if user && !user_signed_in?
       elsif !devise_controller?
         redirect_to new_dev_session_path
       end
     end

    def update_headers_to_disable_caching
      response.headers['Cache-Control'] = 'no-cache, no-cache="set-cookie", no-store, private, proxy-revalidate'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = '-1'
    end
end

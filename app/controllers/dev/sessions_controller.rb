class Dev::SessionsController < ApplicationController
  skip_before_action :dev_auto_login
  skip_before_action :authenticate_user!

  def new
    @users = User.order(:username)
  end

  def create
    session[:dev_user_id] = params[:user_id]
    redirect_to root_path
  end

  def destroy
    session.delete(:dev_user_id)
    sign_out(:user)
    redirect_to new_dev_session_path
  end
end

class UsersController < ApplicationController
  def index
    unless current_user&.admin? || current_user&.owner?
      redirect_to root_path, alert: "Not authorised"
    end
    @users = User.all
  end

  def show
    unless current_user&.admin? || current_user&.owner?
      redirect_to root_path, alert: "Not authorised"
    end
    @user = User.find(params[:id])
  end

  def update
    unless current_user&.admin? || current_user&.owner?
      redirect_to root_path, alert: "Not authorised"
    end
    @user = User.find(params[:id])
    @user.update(role: params[:user][:role])
    redirect_to users_path, notice: "User role updated"
  end
end
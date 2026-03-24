class UsersController < ApplicationController

  def index
    @users = User.accessible_by(current_ability, :assign_role)
                .order(:role, :email)

    search_term = params.dig(:search, :q)
    role_filter = params.dig(:search, :role)

    if search_term.present?
      query = "%#{search_term}%"
      @users = @users.where("email ILIKE ? OR username ILIKE ?", query, query)
    end

    if role_filter.present?
      @users = @users.where(role: role_filter)
    end
  end



  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    new_role = params[:user][:role].to_sym

    authorize! :assign_role, User.new(role: new_role)

    if @user.update(role: new_role)
      redirect_to users_path, notice: "Role updated"
    else
      redirect_to users_path, alert: "Could not update role"
    end
  end
end

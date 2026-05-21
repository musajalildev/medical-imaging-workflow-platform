# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
        # Define abilities for the user here. For example:
    #
    #   return unless user.present?
    #   can :read, :all
    #   return unless user.admin?
    #   can :manage, :all
    #
    # The first argument to `can` is the action you are giving the user
    # permission to do.
    # If you pass :manage it will apply to every action. Other common actions
    # here are :read, :create, :update and :destroy.
    #
    # The second argument is the resource the user can perform the action on.
    # If you pass :all it will apply to every resource. Otherwise pass a Ruby
    # class of the resource.
    #
    # The third argument is an optional hash of conditions to further filter the
    # objects.
    # For example, here the user can only update published articles.
    #
    #   can :update, Article, published: true
    #
    # See the wiki for details:
    # https://github.com/CanCanCommunity/cancancan/blob/develop/docs/define_check_abilities.md
    # 
    #
    return unless user.present?

    #
    # JOB PERMISSIONS
    #
    if user.owner?
      can :manage, Job
       # jobs can only be completed once they have been assigned
      cannot :complete_job, Job, operator_id: nil
      # unassigning reserved for operators only, re-assign to nil to remove op for admins
      cannot :unassign, Job
      cannot :revert_to_draft, Job

    elsif user.admin?
      can :manage, Job
      cannot :new, Job
      cannot :create, Job
      cannot :update, Job
       # jobs can only be completed once they have been assigned
      cannot :complete_job, Job, operator_id: nil
      # unassigning reserved for operators only, re-assign to nil to remove op for admins
      cannot :unassign, Job
      cannot :revert_to_draft, Job

    elsif user.operator?
      can :read, Job
      cannot :read, Job, status: Job.statuses[:draft]
      can :update_status, Job, operator_id: user.id
      can :cancel_job, Job, operator_id: user.id
      can :complete_job, Job, operator_id: user.id
      can :upload_output, Job, operator_id: user.id, status: Job.statuses.except("complete").values
      can :self_assign, Job
      can :unassign, Job, operator_id: user.id

    elsif user.client?
      can :read, Job, client_id: user.id
      can :create, Job
      can :update, Job, client_id: user.id
      can :edit, Job, client_id: user.id
      can :destroy, Job, client_id: user.id, status: Job.statuses[:draft]
      can :revert_to_draft, Job, client_id: user.id, operator_id: nil
      can :submit_draft, Job, client_id: user.id, status: Job.statuses[:draft]
      # client can only change status when no operator is assigned yet and its not a draft
      can :update_status, Job, client_id: user.id, operator_id: nil
      cannot :update_status, Job, status: Job.statuses[:draft]
    end

    #
    # USER MANAGEMENT PERMISSIONS
    #
    if user.admin?
      admin_roles = ["unassigned", "client", "operator"]

      can :read, User, role: admin_roles
      can :assign_role, User, role: admin_roles
      can :update, User, role: admin_roles
    end

    if user.owner?
      can :read, User
      can :assign_role, User
      can :update, User
    end

    #
    # OTHER PERMISSIONS
    #
    unless user.admin? || user.owner? || user.unassigned?
      can :help, :pages
      can :send_help_email, :pages
    end
    if user.unassigned?
      can :sign_up, :pages
      can :send_sign_up_email, :pages
    end
  end
end

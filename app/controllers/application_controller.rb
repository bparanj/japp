class ApplicationController < ActionController::Base
  include Clearance::Controller

  protected

  def require_admin
    return if current_user.admin?

    flash['notice'] = 'You are not authorized to view this page'
    redirect_to sign_in_url
  end
end

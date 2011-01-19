class ApplicationController < ActionController::Base
  protect_from_forgery
  helper_method :target, :username, :password, :credentials_saved?

  protected

  def director_credentials_required
    credentials_saved? || ask_for_credentials
  end

  def ask_for_credentials
    respond_to do |format|
      format.html { redirect_to login_url }
      format.json { render :status => 403, :text => "Forbidden" }
    end
  end

  def credentials_saved?
    target.present? && username.present? && password.present?
  end

  def director
    @director ||= Director.new(target, username, password)
  end

  def target
    session[:target]
  end

  def username
    session[:username]
  end

  def password
    session[:password]
  end
  
end

class SessionsController < ApplicationController

  def new
    @page_title = "Log in"
  end

  def login
    flash[:target]   = params[:target]
    flash[:username] = params[:username]
    flash[:password] = params[:password]
    
    if params[:target].blank? || params[:username].blank? || params[:password].blank?
      redirect_to login_url, :flash => { :error => "Please provide target, username and password to log in" }
    else
      @director = Director.new(params[:target], params[:username], params[:password])

      if @director.authenticated?
        session[:target]   = params[:target]
        session[:username] = params[:username]
        session[:password] = params[:password]
        redirect_to root_url
      else
        redirect_to login_url, :flash => { :error => "Cannot log in with these credentials, please try again" }
      end
    end

  rescue Director::DirectorError => e
    redirect_to login_url, :flash => { :error => e.message }
  end

  def logout
    session[:target]   = nil
    session[:username] = nil
    session[:password] = nil    
    redirect_to login_url
  end
  
end

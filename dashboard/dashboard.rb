require "sinatra"

module Bosh; module Dashboard; end; end

libdir = File.join(File.dirname(__FILE__), "lib")
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "errors"
require "director"
require "helpers"

module Bosh::Dashboard
  class App < Sinatra::Base
    set :haml, :format => :html5, :ugly => true
    set :app_file, __FILE__

    use Rack::Session::Pool

    helpers do
      include Rack::Utils
      include Helpers
      alias_method :h, :escape_html
    end

    before do
      if auth_required?
        if logged_in?
          @director = Bosh::Dashboard::Director.new(target, username, password)
        elsif request.xhr?
          error(403, "Forbidden")
        else
          redirect "/login"
        end
      end
    end

    error do
      exception = request.env["sinatra.error"]
      
      if request.xhr?
        status(500)
        JSON.generate(:error => exception.error_code, :message => exception.message)
      else
        session[:error] = exception
        redirect "/"
      end
    end

    get "/" do
      haml :index
    end

    get "/login" do
      haml :login
    end

    get "/logout" do
      session[:target]   = nil
      session[:username] = nil
      session[:password] = nil
      redirect "/login"
    end

    post "/login" do
      @director = Bosh::Dashboard::Director.new(params[:target], params[:username], params[:password])
      if @director.authenticated?
        session[:target]   = params[:target]
        session[:username] = params[:username]
        session[:password] = params[:password]
        redirect "/"
      else
        redirect "/login"
      end
    end

    get "/stemcells", :provides => "json" do
      @stemcells = @director.list_stemcells
      JSON.generate(:html => haml(:stemcells))
    end

    get "/releases", :provides => "json" do
      @releases = @director.list_releases
      JSON.generate(:html => haml(:releases))      
    end

    get "/deployments", :provides => "json" do
      @deployments = @director.list_deployments
      JSON.generate(:html => haml(:deployments))      
    end

    get "/running_tasks", :provides => "json" do
      @tasks = @director.list_running_tasks
      JSON.generate(:html => haml(:tasks))
    end

    get "/recent_tasks", :provides => "json" do
      @tasks = @director.list_recent_tasks
      JSON.generate(:html => haml(:tasks))
    end
    
  end
end

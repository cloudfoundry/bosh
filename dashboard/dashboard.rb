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

    helpers do
      include Rack::Utils
      include Helpers
      alias_method :h, :escape_html
    end

    before do
      @director = Bosh::Dashboard::Director.new("http://localhost:55420", "admin", "admin")
    end

    error do
      # Provide recovery from director errors
    end

    get "/" do
      haml :index
    end

    get "/stemcells" do
      @stemcells = @director.list_stemcells
      haml :stemcells, :layout => false
    end

    get "/releases" do
      @releases = @director.list_releases
      haml :releases, :layout => false
    end

    get "/deployments" do
      @deployments = @director.list_deployments
      haml :deployments, :layout => false
    end

    get "/running_tasks" do
      @tasks = @director.list_running_tasks
      haml :tasks, :layout => false
    end

    get "/recent_tasks" do
      @tasks = @director.list_recent_tasks
      haml :tasks, :layout => false      
    end
    
  end
end

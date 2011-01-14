require "sinatra"

module Bosh; module Dashboard; end; end

libdir = File.join(File.dirname(__FILE__), "lib")
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "errors"
require "director"

module Bosh::Dashboard
  class App < Sinatra::Base
    set :haml, :format => :html5, :ugly => true
    set :app_file, __FILE__

    before do
      @director = Bosh::Dashboard::Director.new("http://localhost:55420", "admin", "admin")
    end

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
      
      def versioned_js(name)
        "/js/#{name}.js?" + File.mtime(File.join(Sinatra::Application.public, "js", "#{name}.js")).to_i.to_s
      end

      def versioned_css(name)
        "/css/#{name}.css?" + File.mtime(File.join(Sinatra::Application.public, "css", "#{name}.css")).to_i.to_s
      end

      def row_class(i)
        i.to_i % 2 == 0 ? "even" : "odd"
      end
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

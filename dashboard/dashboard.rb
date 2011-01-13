require "sinatra"

module Bosh; module Dashboard; end; end

libdir = File.join(File.dirname(__FILE__), "lib")
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require "errors"
require "director"

module Bosh::Dashboard
  class App < Sinatra::Base
    set :haml, :format => :html5
    set :app_file, __FILE__

    before do
      @director = Bosh::Dashboard::Director.new("http://localhost:55420", "admin", "admin")
    end

    helpers do
      def versioned_js(name)
        "/js/#{name}.js?" + File.mtime(File.join(Sinatra::Application.public, "js", "#{name}.js")).to_i.to_s
      end

      def versioned_css(name)
        "/css/#{name}.css?" + File.mtime(File.join(Sinatra::Application.public, "css", "#{name}.css")).to_i.to_s
      end
    end

    error do
      # Provide recovery from director errors
    end

    get "/" do
      haml :index
    end

    get "/stemcells" do
      JSON.generate(@director.list_stemcells)
    end

    get "/releases" do
      JSON.generate(@director.list_releases)      
    end

    get "/deployments" do
      JSON.generate(@director.list_deployments)
    end
    
  end
end

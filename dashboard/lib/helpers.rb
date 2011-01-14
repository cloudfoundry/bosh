module Bosh::Dashboard
  module Helpers

    def show_error
      error = session[:error]
      session[:error] = nil
      h(error)
    end

    def auth_required?
      request.path_info != "/login"      
    end

    def logged_in?
      target && username && password
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
end


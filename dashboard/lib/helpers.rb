module Bosh::Dashboard
  module Helpers
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


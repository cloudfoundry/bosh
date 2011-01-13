require "sinatra"

module Bosh; module Dashboard; end; end

$:.unshift(File.dirname(__FILE__) + "/lib")

module Bosh::Dashboard
  class App < Sinatra::Base
    get "/" do
      "Dashboard I am"
    end
  end
end

require "sandbox"

module Bosh
  module Spec
    class IntegrationTest
    end
  end
end

RSpec.configure do |c|
  c.filter_run :focus => true if ENV["FOCUS"]
end

def spec_asset(name)
  File.expand_path("../assets/#{name}", __FILE__)
end

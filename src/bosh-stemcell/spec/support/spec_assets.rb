module Bosh::Stemcell
  module SpecAssets
    def spec_asset(name)
      File.expand_path(File.join('..', 'assets', name), File.dirname(__FILE__))
    end
  end
end

RSpec.configure do |config|
  config.include(Bosh::Stemcell::SpecAssets)
end

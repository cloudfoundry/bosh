module Support
  module AssetHelpers
    def asset_content(name)
      File.read(asset_path(name))
    end

    def asset_path(name)
      File.join(SPEC_ROOT, 'assets', name)
    end
  end
end

RSpec.configure do |config|
  config.include(Support::AssetHelpers)
end

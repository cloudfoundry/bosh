module Support
  module AssetHelpers
    def asset_content(asset_name)
      File.read(asset_path(asset_name))
    end

    def asset_path(asset_name)
      File.expand_path(File.join('..', '..', 'assets', asset_name), __FILE__)
    end
  end
end

RSpec.configure do |config|
  config.include(Support::AssetHelpers)
end

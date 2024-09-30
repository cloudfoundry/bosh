module AssetHelpers
  def spec_asset(asset_name)
    File.read(asset(asset_name))
  end

  def asset(asset_name)
    File.expand_path(File.join('..', '..', 'assets', asset_name), __FILE__)
  end
end

RSpec.configure do |config|
  config.include(AssetHelpers)
end

module AssetHelpers
  def spec_asset(filename)
    File.read(asset(filename))
  end

  def asset(filename)
    File.expand_path("../../assets/#{filename}", __FILE__)
  end
end

RSpec.configure do |config|
  config.include(AssetHelpers)
end

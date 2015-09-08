RSpec.configure do |config|
  config.before do
    stub_const('ENV', {
      "STEMCELL_BUILD_NUMBER" => ENV['STEMCELL_BUILD_NUMBER'],
      "CANDIDATE_BUILD_NUMBER" => ENV['CANDIDATE_BUILD_NUMBER'],
      "OS_NAME" => ENV['OS_NAME']
    })
  end
end

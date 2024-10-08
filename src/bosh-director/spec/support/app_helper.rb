module Support
  module AppHelpers
    def fake_app
      allow(Bosh::Director::App).to receive_messages(instance: double('App Instance').as_null_object)
    end
  end
end

RSpec.configure do |config|
  config.include(Support::AppHelpers)
end

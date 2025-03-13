module Support
  module AppHelpers
    def fake_app
      client_double = instance_double(Bosh::Director::Blobstore::BaseClient, can_sign_urls?: false)

      blobstores_double = instance_double(Bosh::Director::Blobstores, blobstore: client_double)

      app_double = instance_double(Bosh::Director::App, blobstores: blobstores_double)

      allow(Bosh::Director::App).to receive_messages(instance: app_double)
    end
  end
end

RSpec.configure do |config|
  config.include(Support::AppHelpers)
end

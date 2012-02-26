module Bosh::Director
  module EncryptionHelper
    def generate_agent_credentials
      [ 'crypt_key', 'sign_key' ].inject({}) do |credentials, key|
        credentials[key] = SecureRandom.base64(48)
        credentials
      end
    end
  end
end
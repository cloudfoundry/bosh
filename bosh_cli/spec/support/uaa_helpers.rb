require 'spec_helper'

module Support
  module UaaHelpers
    def uaa_token_info(client_id, expiration_time)
      token_data = {
        'jti' => '673b0a3e-21c0-49a4-9e48-7043d07c0c22',
        'sub' => 'test',
        'authorities' => ['uaa.none'],
        'scope' =>['uaa.none'],
        'client_id' => client_id,
        'cid' => 'test',
        'azp' => 'test',
        'grant_type' => 'client_credentials',
        'iat' => 1433288433,
        'exp' => expiration_time,
        'iss' => 'https://10.244.0.2/oauth/token',
        'aud' =>['test']
      }
      access_token = CF::UAA::TokenCoder.encode(token_data, {verify: false, skey: ''})

      CF::UAA::TokenInfo.new(
        token_type: 'bearer',
        access_token: access_token
      )
    end
  end
end

module Support
  module UaaHelpers
    def uaa_token_info(token_id, expiration_time = Time.now.to_i + 3600)
      token_data = {
        'jti' => token_id,
        'sub' => 'test',
        'authorities' => ['bosh.admin'],
        'scope' =>['bosh.admin'],
        'client_id' => 'fake-client',
        'cid' => 'test',
        'azp' => 'test',
        'grant_type' => 'client_credentials',
        'iat' => 1433288433,
        'exp' => expiration_time,
        'iss' => 'https://fake-url/oauth/token',
        'aud' =>['test']
      }
      access_token = CF::UAA::TokenCoder.encode(token_data, {verify: false, skey: ''})

      CF::UAA::TokenInfo.new(
        token_type: 'bearer',
        access_token: access_token,
      )
    end
  end
end

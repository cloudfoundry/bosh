require 'spec_helper'
require 'bosh/core/encryption_handler'

module Bosh::Core
  describe EncryptionHandler do
    before(:each) do
      @credentials = EncryptionHandler.generate_credentials
      @cipher = Gibberish::AES.new(@credentials['crypt_key'])
      @sign_key = @credentials['sign_key']
    end

    it 'should encrypt data' do
      handler = EncryptionHandler.new('client_id', @credentials)
      encrypted_data = handler.encrypt('hubba' => 'bubba')

      # double decode is not an error - data need to be serialized before it is
      # signed and then serialized again to be encrypted
      decrypted_data = handler.decode(handler.decode(@cipher.decrypt(encrypted_data))['json_data'])
      expect(decrypted_data['hubba']).to eq('bubba')
    end

    it 'should be signed' do
      handler = EncryptionHandler.new('client_id', @credentials)
      encrypted_data = handler.encrypt('hubba' => 'bubba')

      decrypted_data = handler.decode(@cipher.decrypt(encrypted_data))
      signature = decrypted_data['hmac']
      json_data = decrypted_data['json_data']

      expect(signature).to eq(Gibberish.HMAC(@sign_key, json_data, { digest: :sha256 }))
    end

    it 'should decrypt' do
      handler = EncryptionHandler.new('client_id', @credentials)

      encrypted_data = handler.encrypt('hubba' => 'bubba')
      expect(handler.decrypt(encrypted_data)['hubba']).to eq('bubba')
    end

    it 'should verify signature' do
      handler = EncryptionHandler.new('client_id', @credentials)

      encrypted_data = handler.encrypt('hubba' => 'bubba')

      # build bad data
      manipulated_data = handler.decode(@cipher.decrypt(encrypted_data))
      manipulated_data['hmac'] = 'foo'
      encrypted_manipulated_data = @cipher.encrypt(handler.encode(manipulated_data))

      expect {
        handler.decrypt(encrypted_manipulated_data)
      }.to raise_error(EncryptionHandler::SignatureError,
                           /Expected hmac \(foo\)/)
    end

    it 'should verify session' do
      handler = EncryptionHandler.new('client_id', @credentials)

      encrypted_data = handler.encrypt('knife' => 'fork')

      # build bad data
      decrypted_data = handler.decode(@cipher.decrypt(encrypted_data))

      bad_data = handler.decode(decrypted_data['json_data'])
      bad_data['session_id'] = 'bad_session_data'

      bad_json_data = handler.encode(bad_data)

      manipulated_data = {
        'hmac' => handler.signature(bad_json_data),
        'json_data' => bad_json_data
      }

      encrypted_manipulated_data = @cipher.encrypt(handler.encode(manipulated_data))

      expect {
        handler.decrypt(encrypted_manipulated_data)
      }.to raise_error(EncryptionHandler::SessionError)
    end

    it 'should decrypt for multiple messages' do
      h1 = EncryptionHandler.new('client_id', @credentials)
      h2 = EncryptionHandler.new('client_id', @credentials)
      encrypted_data1 = h1.encrypt('hubba' => 'bubba')
      encrypted_data2 = h1.encrypt('bubba' => 'hubba')

      expect(h2.decrypt(encrypted_data1)['hubba']).to eq('bubba')
      expect(h2.decrypt(encrypted_data2)['bubba']).to eq('hubba')
    end

    it 'should exchange messages' do
      h1 = EncryptionHandler.new('client_id', @credentials)
      h2 = EncryptionHandler.new('client_id', @credentials)

      encrypted_data1 = h1.encrypt('hubba' => 'bubba')
      expect(h2.decrypt(encrypted_data1)['hubba']).to eq('bubba')

      encrypted_data2 = h2.encrypt('kermit' => 'frog')
      expect(h1.decrypt(encrypted_data2)['kermit']).to eq('frog')

      encrypted_data3 = h1.encrypt('frank' => 'zappa')
      expect(h2.decrypt(encrypted_data3)['frank']).to eq('zappa')
    end

    it 'should fail when sequence number is out of order' do
      handler = EncryptionHandler.new('client_id', @credentials)
      encrypted_data1 = handler.encrypt('foo' => 'bar')
      encrypted_data2 = handler.encrypt('baz' => 'bus')

      handler.decrypt(encrypted_data2)

      expect {
        handler.decrypt(encrypted_data1)
      }.to raise_error(EncryptionHandler::SequenceNumberError)
    end

    it 'should handle garbage encrypt args' do
      handler = EncryptionHandler.new('client_id', @credentials)
      expect {
        handler.encrypt('bleh')
      }.to raise_error(ArgumentError)
    end

    it 'should handle garbage decrypt args' do
      handler = EncryptionHandler.new('client_id', @credentials)
      expect {
        handler.decrypt('f')
      }.to raise_error(EncryptionHandler::DecryptionError, /ArgumentError/)

      expect {
        handler.decrypt('fddddddddddddddddddddddddddddddddddddddddddddddddd')
      }.to raise_error(EncryptionHandler::DecryptionError, /CipherError/)
    end
  end
end

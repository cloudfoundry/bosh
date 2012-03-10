require File.expand_path("../../spec_helper", __FILE__)
require "encryption/encryption_handler"

describe Bosh::EncryptionHandler do

  before(:each) do
    @credentials = Bosh::EncryptionHandler.generate_credentials
    @cipher = Gibberish::AES.new(@credentials["crypt_key"])
    @sign_key = @credentials["sign_key"]
  end

  it "should encrypt data" do
    handler = Bosh::EncryptionHandler.new("client_id", @credentials)
    encrypted_data = handler.encrypt('hubba' => 'bubba')

    # double decode is not an error - data need to be serialized before it is
    # signed and then serialized again to be encrypted
    decrypted_data = handler.decode(handler.decode(@cipher.decrypt(encrypted_data))['json_data'])
    decrypted_data['hubba'].should == "bubba"
  end

  it "should be signed" do
    handler = Bosh::EncryptionHandler.new("client_id", @credentials)
    encrypted_data = handler.encrypt("hubba" => "bubba")

    decrypted_data = handler.decode(@cipher.decrypt(encrypted_data))
    signature = decrypted_data["hmac"]
    json_data = decrypted_data["json_data"]

    signature.should == Gibberish::HMAC(@sign_key, json_data, {:digest => :sha256})
  end

  it "should decrypt" do
    handler = Bosh::EncryptionHandler.new("client_id", @credentials)

    encrypted_data = handler.encrypt("hubba" => "bubba")
    handler.decrypt(encrypted_data)["hubba"].should == "bubba"
  end

  it "should verify signature" do
    handler = Bosh::EncryptionHandler.new("client_id", @credentials)

    encrypted_data = handler.encrypt("hubba" => "bubba")

    # build bad data
    manipulated_data = handler.decode(@cipher.decrypt(encrypted_data))
    manipulated_data['hmac'] = "foo"
    encrypted_manipulated_data = @cipher.encrypt(handler.encode(manipulated_data))

    lambda {
      handler.decrypt(encrypted_manipulated_data)
    }.should raise_error(Bosh::EncryptionHandler::SignatureError,
                         /Expected hmac \(foo\)/)
  end

  it "should verify session" do
    handler = Bosh::EncryptionHandler.new("client_id", @credentials)

    encrypted_data = handler.encrypt("knife" => "fork")

    # build bad data
    decrypted_data = handler.decode(@cipher.decrypt(encrypted_data))

    bad_data = handler.decode(decrypted_data['json_data'])
    bad_data["session_id"] = "bad_session_data"

    bad_json_data = handler.encode(bad_data)

    manipulated_data = {
      "hmac" => handler.signature(bad_json_data),
      "json_data" => bad_json_data
    }

    encrypted_manipulated_data = @cipher.encrypt(handler.encode(manipulated_data))

    lambda {
      handler.decrypt(encrypted_manipulated_data)
    }.should raise_error(Bosh::EncryptionHandler::SessionError)
  end

  it "should decrypt for multiple messages" do
    h1 = Bosh::EncryptionHandler.new("client_id", @credentials)
    h2 = Bosh::EncryptionHandler.new("client_id", @credentials)
    encrypted_data1 = h1.encrypt("hubba" => "bubba")
    encrypted_data2 = h1.encrypt("bubba" => "hubba")

    h2.decrypt(encrypted_data1)["hubba"].should == "bubba"
    h2.decrypt(encrypted_data2)["bubba"].should == "hubba"
  end

  it "should exchange messages" do
    h1 = Bosh::EncryptionHandler.new("client_id", @credentials)
    h2 = Bosh::EncryptionHandler.new("client_id", @credentials)

    encrypted_data1 = h1.encrypt("hubba" => "bubba")
    h2.decrypt(encrypted_data1)["hubba"].should == "bubba"

    encrypted_data2 = h2.encrypt("kermit" => "frog")
    h1.decrypt(encrypted_data2)["kermit"].should == "frog"

    encrypted_data3 = h1.encrypt("frank" => "zappa")
    h2.decrypt(encrypted_data3)["frank"].should == "zappa"
  end

  it "should fail when sequence number is out of order" do
    handler =  Bosh::EncryptionHandler.new("client_id", @credentials)
    encrypted_data1 = handler.encrypt("foo" => "bar")
    encrypted_data2 = handler.encrypt("baz" => "bus")

    handler.decrypt(encrypted_data2)

    lambda {
      handler.decrypt(encrypted_data1)
    }.should raise_error(Bosh::EncryptionHandler::SequenceNumberError)
  end

  it "should handle garbage encrypt args" do
    handler =  Bosh::EncryptionHandler.new("client_id", @credentials)
    lambda {
      handler.encrypt("bleh")
    }.should raise_error(ArgumentError)
  end

  it "should handle garbage decrypt args" do
    handler =  Bosh::EncryptionHandler.new("client_id", @credentials)
    lambda {
      handler.decrypt("f")
    }.should raise_error(Bosh::EncryptionHandler::DecryptionError, /TypeError/)

    lambda {
      handler.decrypt("fddddddddddddddddddddddddddddddddddddddddddddddddd")
    }.should raise_error(Bosh::EncryptionHandler::DecryptionError, /CipherError/)
  end

end

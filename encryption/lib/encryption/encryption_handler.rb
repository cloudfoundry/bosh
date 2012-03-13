# Copyright (c) 2009-2012 VMware, Inc.

require "securerandom"
require "gibberish"
require "uuidtools"
require "yajl"

module Bosh
  # Utility class for decrypting/encrypting Director/Agent message exchanges
  class EncryptionHandler

    class CryptError < StandardError; end

    class SessionError < CryptError; end
    class SequenceNumberError < CryptError; end
    class SignatureError < CryptError; end
    class DecryptionError < CryptError; end

    attr_reader :session_id

    def initialize(id, credentials)
      @id = id
      crypt_key = credentials["crypt_key"]
      @cipher = Gibberish::AES.new(crypt_key)
      @sign_key = credentials["sign_key"]
      @session_id = nil
      @session_sequence_number = 0

      initiate_sequence_number
    end

    def initiate_sequence_number
      @sequence_number = Time.now.to_i + SecureRandom.random_number(1 << 32)
    end

    def encrypt(data)
      unless data.is_a?(Hash)
        raise ArgumentError
      end

      unless @session_id
        start_session
      end

      encapsulated_data = data.dup
      # Add encrytpion related metadata before signing and encrypting
      @sequence_number += 1
      encapsulated_data["sequence_number"] = @sequence_number
      encapsulated_data["client_id"] = @id
      encapsulated_data["session_id"] = @session_id

      signed_data = sign(encapsulated_data)
      encrypted_data = @cipher.encrypt(encode(signed_data))
      encrypted_data
    end

    def sign(encapsulated_data)
      data_json = encode(encapsulated_data)
      hmac = signature(data_json)
      signed_data = {"hmac" => hmac, "json_data" => data_json }
      signed_data
    end

    def decrypt(encrypted_data)
      begin
        decrypted_data = @cipher.decrypt(encrypted_data)
      rescue Exception => e
        raise DecryptionError, e.inspect
      end

      data = Yajl::Parser.new.parse(decrypted_data)

      # TODO: check if we should verify client_id?
      verify_signature(data)
      decoded_data = decode(data["json_data"])
      verify_session(decoded_data)
      decoded_data
    end

    def start_session
      @session_id = UUIDTools::UUID.random_create.to_s
    end

    def verify_signature(data)
      hmac = data["hmac"]
      json_data = data["json_data"]

      json_hmac = signature(json_data)
      unless hmac == json_hmac
        raise SignatureError, "Expected hmac (#{hmac}), got (#{json_hmac})"
      end
    end

    def verify_session(decrypted_data)
      # If you are the receiver of a session - use session_id from payload
      if @session_id.nil?
        if !decrypted_data["session_id"].nil?
          @session_id = decrypted_data["session_id"]
        else
          raise SessionError, "no session_id"
        end
      end

      unless decrypted_data["session_id"] == @session_id
        raise SessionError, "session_id mismatch"
      end

      sender_sequence_number = decrypted_data["sequence_number"].to_i
      if sender_sequence_number > @session_sequence_number
        @session_sequence_number = sender_sequence_number
      else
        raise SequenceNumberError, "invalid sequence number"
      end
    end

    def signature(sign_data)
      Gibberish::HMAC(@sign_key, sign_data, {:digest => :sha256})
    end

    def encode(data)
      Yajl::Encoder.encode(data)
    end

    def decode(json)
      Yajl::Parser.new.parse(json)
    end

    def self.generate_credentials
      ["crypt_key", "sign_key"].inject({}) do |credentials, key|
        credentials[key] = SecureRandom.base64(48)
        credentials
      end
    end
  end

end

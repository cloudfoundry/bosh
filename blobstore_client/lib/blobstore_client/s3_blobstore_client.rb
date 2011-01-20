require "openssl"
require "digest/sha1"
require "base64"
require "aws/s3"
require "uuidtools"

module Bosh
  module Blobstore

    class S3BlobstoreClient < Client

      DEFAULT_CIPHER_NAME = "aes-128-cbc"

      attr_reader :bucket_name, :encryption_key

      def initialize(options)
        options = options.dup
        options.each_key do |key|
          options[key.to_sym] = options[key] if key.is_a?(String)
        end

        @bucket_name    = options[:bucket_name]
        @encryption_key = options[:encryption_key]

        aws_options = {
          :access_key_id     => options[:access_key_id],
          :secret_access_key => options[:secret_access_key]
        }

        AWS::S3::Base.establish_connection!(aws_options)
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to initialize S3 blobstore: #{e.message}"
      end

      def create(contents)
        object_id = generate_object_id
        payload   = encrypt(contents)
        
        AWS::S3::S3Object.store(object_id, Base64.encode64(payload), bucket_name)
        object_id
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to create object, S3 response error: #{e.message}"
      end

      def get(object_id)
        object = AWS::S3::S3Object.find(object_id, bucket_name)
        decrypt(Base64.decode64(object.value))
      rescue AWS::S3::NoSuchKey => e
        raise NotFound, "S3 object `#{object_id}' not found"
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to find object `#{object_id}', S3 response error: #{e.message}"        
      end

      def delete(object_id)
        AWS::S3::S3Object.delete(object_id, bucket_name)
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to delete object `#{object_id}', S3 response error: #{e.message}"
      end

      protected

      def generate_object_id
        UUIDTools::UUID.random_create.to_s
      end

      def encrypt(clear_text)
        cipher = OpenSSL::Cipher::Cipher.new(DEFAULT_CIPHER_NAME)
        cipher.encrypt
        cipher.key = Digest::SHA1.digest(encryption_key)[0..cipher.key_len-1]
        encrypted = cipher.update(clear_text)

        encrypted << cipher.final
        encrypted
      rescue StandardError => e
        raise BlobstoreError, "Encryption error: #{e}"
      end

      def decrypt(encrypted)
        cipher = OpenSSL::Cipher::Cipher.new(DEFAULT_CIPHER_NAME)
        cipher.decrypt
        cipher.key = Digest::SHA1.digest(encryption_key)[0..cipher.key_len-1]

        decrypted = cipher.update(encrypted)
        decrypted << cipher.final
        decrypted
      rescue StandardError => e
        raise BlobstoreError, "Decryption error: #{e}"
      end
      
    end
  end
end

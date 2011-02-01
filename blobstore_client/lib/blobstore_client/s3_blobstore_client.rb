require "openssl"
require "digest/sha1"
require "base64"
require "aws/s3"
require "uuidtools"

module Bosh
  module Blobstore

    class S3BlobstoreClient < BaseClient

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

      def create_file(file)
        object_id = generate_object_id
        temp_path do |path|
          File.open(path, "w") do |temp_file|
            encrypt_stream(file, temp_file)
          end
          File.open(path, "r") do |temp_file|
            AWS::S3::S3Object.store(object_id, temp_file, bucket_name)
          end
        end
        object_id
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to create object, S3 response error: #{e.message}"
      end

      def get_file(object_id, file)
        object = AWS::S3::S3Object.find(object_id, bucket_name)
        decrypt_stream(lambda { |callback| object.value { |segment| callback.call(segment) } }, file)
      rescue AWS::S3::NoSuchKey => e
        raise NotFound, "S3 object '#{object_id}' not found"
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to find object '#{object_id}', S3 response error: #{e.message}"
      end

      def delete(object_id)
        AWS::S3::S3Object.delete(object_id, bucket_name)
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to delete object '#{object_id}', S3 response error: #{e.message}"
      end

      protected

      def generate_object_id
        UUIDTools::UUID.random_create.to_s
      end

      def encrypt_stream(from, to)
        cipher = OpenSSL::Cipher::Cipher.new(DEFAULT_CIPHER_NAME)
        cipher.encrypt
        cipher.key = Digest::SHA1.digest(encryption_key)[0..cipher.key_len-1]

        to_stream = write_stream(to)
        read_stream(from) { |segment| to_stream.call(cipher.update(segment)) }
        to_stream.call(cipher.final)
      rescue StandardError => e
        raise BlobstoreError, "Encryption error: #{e}"
      end

      def decrypt_stream(from, to)
        cipher = OpenSSL::Cipher::Cipher.new(DEFAULT_CIPHER_NAME)
        cipher.decrypt
        cipher.key = Digest::SHA1.digest(encryption_key)[0..cipher.key_len-1]

        to_stream = write_stream(to)
        read_stream(from) { |segment| to_stream.call(cipher.update(segment)) }
        to_stream.call(cipher.final)
      rescue StandardError => e
        raise BlobstoreError, "Decryption error: #{e}"
      end

      def read_stream(stream, &block)
        if stream.respond_to?(:read)
          while contents = stream.read(32768)
            block.call(contents)
          end
        elsif stream.kind_of?(Proc)
          stream.call(block)
        end
      end

      def write_stream(stream)
        if stream.respond_to?(:write)
          lambda { |contents| stream.write(contents)}
        elsif stream.kind_of?(Proc)
          stream
        end
      end

    end
  end
end

# Copyright (c) 2009-2012 VMware, Inc.

require "openssl"
require "digest/sha1"
require "base64"
require "aws/s3"
require "uuidtools"

module Bosh
  module Blobstore

    class S3BlobstoreClient < BaseClient

      ENDPOINT = "https://s3.amazonaws.com"
      DEFAULT_CIPHER_NAME = "aes-128-cbc"

      attr_reader :bucket_name, :encryption_key

      # Blobstore client for S3 with optional object encryption
      # @param [Hash] options S3connection options
      # @option options [Symbol] bucket_name
      # @option options [Symbol, optional] encryption_key optional encryption
      #   key that is applied before the object is sent to S3
      # @option options [Symbol, optional] access_key_id
      # @option options [Symbol, optional] secret_access_key
      # @note If access_key_id and secret_access_key are not present, the
      #   blobstore client operates in read only mode as a
      #   simple_blobstore_client
      def initialize(options)
        super(options)
        @bucket_name    = @options[:bucket_name]
        @encryption_key = @options[:encryption_key]

        aws_options = {
          :access_key_id     => @options[:access_key_id],
          :secret_access_key => @options[:secret_access_key],
          :use_ssl           => true,
          :port              => 443
        }

        # using S3 without credentials is a special case:
        # it is really the simple blobstore client with a bucket name
        if read_only?
          unless @options[:bucket_name] || @options[:bucket]
            raise BlobstoreError, "bucket name required"
          end
          @options[:bucket] ||= @options[:bucket_name]
          @options[:endpoint] ||= S3BlobstoreClient::ENDPOINT
          @simple = SimpleBlobstoreClient.new(@options)
        else
          AWS::S3::Base.establish_connection!(aws_options)
        end

      rescue AWS::S3::S3Exception => e
        raise BlobstoreError, "Failed to initialize S3 blobstore: #{e.message}"
      end

      def create_file(file)
        raise BlobstoreError, "unsupported action" if @simple

        object_id = generate_object_id

        if @encryption_key
          temp_path do |path|
            File.open(path, "w") do |temp_file|
              encrypt_stream(file, temp_file)
            end
            File.open(path, "r") do |temp_file|
              AWS::S3::S3Object.store(object_id, temp_file, bucket_name)
            end
          end
        elsif file.is_a?(String)
          File.open(file, "r") do |temp_file|
            AWS::S3::S3Object.store(object_id, temp_file, bucket_name)
          end
        else # Ruby 1.8 passes a File
          AWS::S3::S3Object.store(object_id, file, bucket_name)
        end

        object_id
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError,
          "Failed to create object, S3 response error: #{e.message}"
      end

      def get_file(object_id, file)
        return @simple.get_file(object_id, file) if @simple

        object = AWS::S3::S3Object.find(object_id, bucket_name)
        from = lambda { |callback|
          object.value { |segment|
            # Looks like the aws code calls this block even if segment is empty.
            # Ideally it should be fixed upstream in the aws gem.
            unless segment.empty?
              callback.call(segment)
            end
          }
        }
        if @encryption_key
          decrypt_stream(from, file)
        else
          to_stream = write_stream(file)
          read_stream(from) { |segment| to_stream.call(segment) }
        end
      rescue AWS::S3::NoSuchKey => e
        raise NotFound, "S3 object '#{object_id}' not found"
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError,
          "Failed to find object '#{object_id}', S3 response error: #{e.message}"
      end

      def delete(object_id)
        raise BlobstoreError, "unsupported action" if @simple

        AWS::S3::S3Object.delete(object_id, bucket_name)
      rescue AWS::S3::S3Exception => e
        raise BlobstoreError,
          "Failed to delete object '#{object_id}', S3 response error: #{e.message}"
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

      def read_only?
        @options[:access_key_id].nil? && @options[:secret_access_key].nil?
      end

    end
  end
end

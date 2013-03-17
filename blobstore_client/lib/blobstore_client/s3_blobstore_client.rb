# Copyright (c) 2009-2012 VMware, Inc.

require "openssl"
require "digest/sha1"
require "base64"
require "aws"
require "securerandom"

module Bosh
  module Blobstore

    class S3BlobstoreClient < BaseClient

      ENDPOINT = "https://s3.amazonaws.com"
      DEFAULT_CIPHER_NAME = "aes-128-cbc"

      attr_reader :bucket_name, :encryption_key, :simple

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
          if @encryption_key
            raise BlobstoreError, "can't use read-only with an encryption key"
          end

          unless @options[:bucket_name] || @options[:bucket]
            raise BlobstoreError, "bucket name required"
          end

          @options[:bucket] ||= @options[:bucket_name]
          @options[:endpoint] ||= S3BlobstoreClient::ENDPOINT
          @simple = SimpleBlobstoreClient.new(@options)
        else
          @s3 = AWS::S3.new(aws_options)
        end

      rescue AWS::Errors::Base => e
        raise BlobstoreError, "Failed to initialize S3 blobstore: #{e.message}"
      end

      # @param [File] file file to store in S3
      def create_file(object_id, file)
        raise BlobstoreError, "unsupported action" if @simple

        object_id ||= generate_object_id

        file = encrypt_file(file) if @encryption_key

        # in Ruby 1.8 File doesn't respond to :path
        path = file.respond_to?(:path) ? file.path : file
        store_in_s3(path, object_id)

        object_id
      rescue AWS::Errors::Base => e
        raise BlobstoreError,
          "Failed to create object, S3 response error: #{e.message}"
      ensure
        FileUtils.rm(file) if @encryption_key
      end

      # @param [String] object_id object id to retrieve
      # @param [File] file file to store the retrived object in
      def get_file(object_id, file)
        return @simple.get_file(object_id, file) if @simple

        if @encryption_key
          cipher = OpenSSL::Cipher::Cipher.new(DEFAULT_CIPHER_NAME)
          cipher.decrypt
          cipher.key = Digest::SHA1.digest(encryption_key)[0..cipher.key_len-1]
        end

        object = get_object_from_s3(object_id)
        object.read do |chunk|
          if @encryption_key
            file.write(cipher.update(chunk))
          else
            file.write(chunk)
          end
        end
        file.write(cipher.final) if @encryption_key

      rescue AWS::S3::Errors::NoSuchKey => e
        raise NotFound, "S3 object '#{object_id}' not found"
      rescue AWS::Errors::Base => e
        raise BlobstoreError,
          "Failed to find object '#{object_id}', " +
              "S3 response error: #{e.message}"
      end

      # @param [String] object_id object id to delete
      def delete_object(object_id)
        raise BlobstoreError, "unsupported action" if @simple

        object = get_object_from_s3(object_id)
        unless object.exists?
          raise BlobstoreError, "no such object: #{object_id}"
        end
        object.delete
      rescue AWS::Errors::Base => e
        raise BlobstoreError,
          "Failed to delete object '#{object_id}', " +
              "S3 response error: #{e.message}"
      end

      def object_exists?(object_id)
        return simple.exists?(object_id) if simple

        get_object_from_s3(object_id).exists?
      end

      protected

      # @param [String] oid object id
      # @return [AWS::S3::S3Object] S3 object
      def get_object_from_s3(oid)
        @s3.buckets[bucket_name].objects[oid]
      end

      # @param [String] path path to file which will be stored in S3
      # @param [String] oid object id
      # @return [void]
      def store_in_s3(path, oid)
        s3_object = get_object_from_s3(oid)
        raise BlobstoreError, "object id #{oid} is already in use" if s3_object.exists?
        File.open(path, "r") do |temp_file|
          s3_object.write(temp_file)
        end
      end

      def encrypt_file(file)
        cipher = OpenSSL::Cipher::Cipher.new(DEFAULT_CIPHER_NAME)
        cipher.encrypt
        cipher.key = Digest::SHA1.digest(encryption_key)[0..cipher.key_len-1]

        path = temp_path
        File.open(path, "w") do |temp_file|
          while block = file.read(32768)
            temp_file.write(cipher.update(block))
          end
          temp_file.write(cipher.final)
        end

        path
      end

      def generate_object_id
        SecureRandom.uuid
      end

      def read_only?
        @options[:access_key_id].nil? && @options[:secret_access_key].nil?
      end

    end
  end
end

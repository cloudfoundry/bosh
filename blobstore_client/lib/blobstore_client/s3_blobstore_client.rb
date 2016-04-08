require 'openssl'
require 'digest/sha1'
require 'base64'
require 'aws-sdk-resources'
require 'securerandom'

module Bosh
  module Blobstore
    class S3BlobstoreClient < BaseClient

      ENDPOINT = 'https://s3.amazonaws.com'
      DEFAULT_REGION = 'us-east-1'
      # hack to get the v2 AWS SDK to behave with S3-compatible blobstores
      BLANK_REGION = ' '

      attr_reader :simple

      # Blobstore client for S3
      # @param [Hash] options S3connection options
      # @option options [Symbol] bucket_name
      #   key that is applied before the object is sent to S3
      # @option options [Symbol, optional] access_key_id
      # @option options [Symbol, optional] secret_access_key
      # @note If access_key_id and secret_access_key are not present, the
      #   blobstore client operates in read only mode as a
      #   simple_blobstore_client
      def initialize(options)
        super(options)

        @aws_options = build_aws_options({
          bucket_name: @options[:bucket_name],
          use_ssl: @options.fetch(:use_ssl, true),
          host: @options[:host],
          port: @options[:port],
          region: @options[:region] || DEFAULT_REGION,
          s3_force_path_style: @options.fetch(:s3_force_path_style, false),
          ssl_verify_peer:  @options.fetch(:ssl_verify_peer, true),
          credentials_source: @options.fetch(:credentials_source, 'static'),
          access_key_id: @options[:access_key_id],
          secret_access_key: @options[:secret_access_key],
          signature_version: @options[:signature_version]
        })

        # using S3 without credentials is a special case:
        # it is really the simple blobstore client with a bucket name
        if read_only?
          unless @options[:bucket_name] || @options[:bucket]
            raise BlobstoreError, 'bucket name required'
          end

          @options[:bucket] ||= @options[:bucket_name]
          @options[:endpoint] ||= S3BlobstoreClient::ENDPOINT
          @simple = SimpleBlobstoreClient.new(@options)
        end

      rescue Aws::S3::Errors::ServiceError => e
        raise BlobstoreError, "Failed to initialize S3 blobstore: #{e.code} : #{e.message}"
      end

      # @param [File] file file to store in S3
      def create_file(object_id, file)
        raise BlobstoreError, 'unsupported action' if @simple

        object_id ||= generate_object_id

        # in Ruby 1.8 File doesn't respond to :path
        path = file.respond_to?(:path) ? file.path : file
        store_in_s3(path, full_oid_path(object_id))

        object_id
      rescue Aws::S3::Errors::ServiceError => e
        raise BlobstoreError, "Failed to create object, S3 response error code #{e.code}: #{e.message}"
      end

      # @param [String] object_id object id to retrieve
      # @param [File] file file to store the retrived object in
      def get_file(object_id, file)
        object_id = full_oid_path(object_id)
        return @simple.get_file(object_id, file) if @simple

        s3_object = Aws::S3::Object.new({:key => object_id}.merge(@aws_options))
        s3_object.get do |chunk|
          file.write(chunk)
        end

      rescue Aws::S3::Errors::NoSuchKey => e
        raise NotFound, "S3 object '#{object_id}' not found"
      rescue Aws::S3::Errors::ServiceError => e
        raise BlobstoreError, "Failed to find object '#{object_id}', S3 response error code #{e.code}: #{e.message}"
      end

      # @param [String] object_id object id to delete
      def delete_object(object_id)
        raise BlobstoreError, 'unsupported action' if @simple
        object_id = full_oid_path(object_id)

        s3_object = Aws::S3::Object.new({:key => object_id}.merge(@aws_options))
        # TODO: don't blow up if we are cannot find an object we are trying to
        # delete anyway
        raise NotFound, "Object '#{object_id}' is not found" unless s3_object.exists?

        s3_object.delete
      rescue Aws::S3::Errors::ServiceError => e
        raise BlobstoreError, "Failed to delete object '#{object_id}', S3 response error code #{e.code}: #{e.message}"
      end

      def object_exists?(object_id)
        object_id = full_oid_path(object_id)
        return simple.exists?(object_id) if simple

        # Hack to get the Aws SDK to redirect to the correct region on
        # subsequent requests
        unless @region_configured
          s3 = Aws::S3::Client.new(@aws_options.reject{|k| k == :bucket_name})
          s3.list_objects({bucket: @aws_options[:bucket_name]})
          @region_configured = true
        end

        Aws::S3::Object.new({:key => object_id}.merge(@aws_options)).exists?
      end

      protected

      # @param [String] path path to file which will be stored in S3
      # @param [String] oid object id
      # @return [void]
      def store_in_s3(path, oid)
        raise BlobstoreError, "object id #{oid} is already in use" if object_exists?(oid)

        s3_object = Aws::S3::Object.new({:key => oid}.merge(@aws_options))
        multipart_threshold = @options.fetch(:s3_multipart_threshold, 16_777_216)
        s3_object.upload_file(path, {content_type: "application/octet-stream", multipart_threshold: multipart_threshold})
        nil
      end

      def read_only?
        (@options[:credentials_source] == 'static' ||
        @options[:credentials_source].nil?) &&
        @options[:access_key_id].nil? &&
        @options[:secret_access_key].nil?
      end

      def full_oid_path(object_id)
         @options[:folder] ?  @options[:folder] + '/' + object_id : object_id
      end

      def use_v4_signing?(options)
        case options[:signature_version]
          when '4'
            true
          when '2'
            false
          else
            region = options[:region]
            (region == 'eu-central-1' || region == 'cn-north-1')
        end
      end

      def aws_credentials(credentials_source, access_key_id, secret_access_key)
        creds = {}
        # credentials_source could be static (default) or env_or_profile
        # static credentials must be included in aws_properties
        # env_or_profile credentials will use the Aws DefaultCredentialsProvider
        # to find Aws credentials in environment variables or EC2 instance profiles
        case credentials_source
          when 'static'
            creds[:access_key_id]     = access_key_id
            creds[:secret_access_key] = secret_access_key

          when 'env_or_profile'
            if !access_key_id.nil? || !secret_access_key.nil?
              raise BlobstoreError, "can't use access_key_id or secret_access_key with env_or_profile credentials_source"
            end
          else
            raise BlobstoreError, 'invalid credentials_source'
        end
        return creds
      end

      def build_aws_options(options)
        aws_options = {
          bucket_name: options[:bucket_name],
          region: options[:region],
          force_path_style: options[:s3_force_path_style],
          ssl_verify_peer: options[:ssl_verify_peer],
        }

        unless options[:host].nil?
          host = options[:host]
          protocol = options[:use_ssl] ? 'https' : 'http'
          uri = options[:port].nil? ? host : "#{host}:#{options[:port]}"
          aws_options[:endpoint] = "#{protocol}://#{uri}"
          aws_options[:region] = BLANK_REGION
        end

        aws_options[:signature_version] = 's3' unless use_v4_signing?(options)

        creds = aws_credentials(options[:credentials_source], options[:access_key_id], options[:secret_access_key])
        aws_options.merge!(creds)

        aws_options
      end
    end
  end
end

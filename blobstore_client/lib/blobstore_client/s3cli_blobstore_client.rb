require 'openssl'
require 'digest/sha1'
require 'base64'
require 'securerandom'
require 'open3'
require 'json'

module Bosh
  module Blobstore
    class S3cliBlobstoreClient < BaseClient

      # Blobstore client for S3, using s3cli Go version
      # @param [Hash] options S3connection options
      # @option options [Symbol] bucket_name
      #   key that is applied before the object is sent to S3
      # @option options [Symbol, optional] access_key_id
      # @option options [Symbol, optional] secret_access_key
      # @option options [Symbol] s3cli_path
      #   path to s3cli binary
      # @option options [Symbol, optional] s3cli_config_path
      #   path to store configuration files
      # @note If access_key_id and secret_access_key are not present, the
      #   blobstore client operates in read only mode
      def initialize(options)
        super(options)

        @s3cli_path = @options.fetch(:s3cli_path)
        unless Kernel.system("#{@s3cli_path} --v", out: "/dev/null", err: "/dev/null")
          raise BlobstoreError, "Cannot find s3cli executable. Please specify s3cli_path parameter"
        end

        @s3cli_options = {
          bucket_name: @options[:bucket_name],
          use_ssl: @options.fetch(:use_ssl, true),
          host: @options[:host],
          port: @options[:port],
          region: @options[:region],
          ssl_verify_peer:  @options.fetch(:ssl_verify_peer, true),
          credentials_source: @options.fetch(:credentials_source, 'none'),
          access_key_id: @options[:access_key_id],
          secret_access_key: @options[:secret_access_key],
          signature_version: @options[:signature_version]
        }

        @s3cli_options.reject! {|k,v| v.nil?}

        if  @options[:access_key_id].nil? &&
            @options[:secret_access_key].nil?
              @options[:credentials_source] = 'none'
        end

        @config_file = write_config_file(@options.fetch(:s3cli_config_path, nil))
      end

      # @param [File] file file to store in S3
      def create_file(object_id, file)
        object_id ||= generate_object_id
        # in Ruby 1.8 File doesn't respond to :path
        path = file.respond_to?(:path) ? file.path : file

        store_in_s3(path, full_oid_path(object_id))

        object_id
      end

      # @param [String] object_id object id to retrieve
      # @param [File] file file to store the retrived object in
      def get_file(object_id, file)
        begin
        out, err, status = Open3.capture3("#{@s3cli_path} -c #{@config_file} get #{object_id} #{file.path}")
        rescue Exception => e
          raise BlobstoreError, e.inspect
        end
        raise BlobstoreError, "Failed to download S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
      end

      # @param [String] object_id object id to delete
      def delete_object(object_id)
        begin
          out, err, status = Open3.capture3("#{@s3cli_path} -c #{@config_file} delete #{object_id}")
        rescue Exception => e
          raise BlobstoreError, e.inspect
        end
        raise BlobstoreError, "Failed to delete S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
      end

      def object_exists?(object_id)
        begin
          out, err, status = Open3.capture3("#{@s3cli_path} -c #{@config_file} exists #{object_id}")
          if status.exitstatus == 0
            return true
          end
          if status.exitstatus == 3
            return false
          end
        rescue Exception => e
          raise BlobstoreError, e.inspect
        end
        raise BlobstoreError, "Failed to check existence of S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
      end

      protected

      # @param [String] path path to file which will be stored in S3
      # @param [String] oid object id
      # @return [void]
      def store_in_s3(path, oid)
        begin
        out, err, status = Open3.capture3("#{@s3cli_path} -c #{@config_file} put #{path} #{oid}")
        rescue Exception => e
          raise BlobstoreError, e.inspect
        end
        raise BlobstoreError, "Failed to create S3 object, code #{status.exitstatus}, output: '#{out}', error: '#{err}'" unless status.success?
      end

      def full_oid_path(object_id)
         @options[:folder] ?  @options[:folder] + '/' + object_id : object_id
      end

      def write_config_file(config_file_dir = nil)
        config_file_dir = Dir::tmpdir unless config_file_dir
        Dir.mkdir(config_file_dir) unless File.exists?(config_file_dir)
        random_name = "s3_blobstore_config-#{SecureRandom.uuid}"
        config_file = File.join(config_file_dir, random_name)
        config_data = JSON.dump(@s3cli_options)

        File.write(config_file, config_data)
        config_file
      end

    end
  end
end

require 'tmpdir'
require 'securerandom'

module Bosh
  module Blobstore
    class BaseClient < Client
      attr_reader :logger

      # @param [Hash] options blobstore specific options
      def initialize(options)
        @options = Bosh::Common.symbolize_keys(options)
        @logger = Bosh::Director::TaggedLogger.new(Bosh::Director::Config.logger, 'blobstore')
      end

      # Saves a file or a string to the blobstore.
      # if it is a String, it writes it to a temp file
      # then calls create_file() with the (temp) file
      # @overload create(contents, id=nil)
      #   @param [String] contents contents to upload
      #   @param [String] id suggested object id, if nil a uuid is generated
      # @overload create(file, id=nil)
      #   @param [File] file file to upload
      #   @param [String] id suggested object id, if nil a uuid is generated
      # @return [String] object id of the created blobstore object
      def create(contents, id = nil)
        start_time = Time.now
        log_message = id

        if contents.kind_of?(File)
          logger.debug("creating '#{log_message}' start: #{start_time}")
          create_file(id, contents)
        else
          temp_path do |path|
            log_message = path

            logger.debug("creating '#{log_message}' start: #{start_time}")
            File.open(path, 'w') do |file|
              file.write(contents)
            end

            return create_file(id, File.open(path, 'r'))
          end
        end
      rescue BlobstoreError => e
        raise e
      rescue Exception => e
        raise BlobstoreError,
              sprintf('Failed to create object, underlying error: %s %s', e.inspect, e.backtrace.join("\n"))
      ensure
        logger.debug("creating '#{log_message}' (took #{Time.now - start_time})")
      end

      # Get an object from the blobstore.
      # @param [String] id object id
      # @param [File] file where to store the fetched object
      # @param [Hash] options for individual request configuration
      # @return [String] the object contents if the file parameter is nil
      def get(id, file = nil, options = {})
        start_time = Time.now
        logger.debug("getting '#{id}' start: #{start_time}")

        if file
          get_file(id, file)
          file.flush
        else
          result = nil
          temp_path do |path|
            File.open(path, 'w') { |f| get_file(id, f) }
            result = File.open(path, 'r') { |f| f.read }
          end
          logger.debug("getting '#{id}' (took #{Time.now - start_time})")
          result
        end
      rescue BlobstoreError => e
        raise e
      rescue Exception => e
        raise BlobstoreError,
              sprintf('Failed to fetch object, underlying error: %s %s', e.inspect, e.backtrace.join("\n"))
      ensure
        logger.debug("getting '#{id}' (took #{Time.now - start_time})")
      end

      # @return [void]
      def delete(oid)
        start_time = Time.now
        logger.debug("deleting '#{oid}' start: #{start_time}")
        begin
          delete_object(oid)
        rescue Exception => e
          raise e
        ensure
          logger.debug("deleting '#{oid}' (took #{Time.now - start_time})")
        end
      end

      # @return [Boolean]
      def exists?(oid)
        start_time = Time.now
        logger.debug("checking existence of '#{oid}' start: #{start_time}")
        begin
          object_exists?(oid)
        rescue Exception => e
            raise e
        ensure
          logger.debug("checking existence of '#{oid}' (took #{Time.now - start_time})")
        end
      end

      def sign(oid, verb = 'get')
        duration = '24h'
        sign_url(oid, verb, duration)
      end

      def signing_enabled?
        @options[:enable_signed_urls]
      end

      def generate_object_id
        SecureRandom.uuid
      end

      protected

      # @return [String] the id
      def create_file(id, file)
        # needs to be implemented in each subclass
        not_supported
      end

      def get_file(id, file)
        # needs to be implemented in each subclass
        not_supported
      end

      def delete_object(oid)
        # needs to be implemented in each subclass
        not_supported
      end

      def object_exists?(oid)
        # needs to be implemented in each subclass
        not_supported
      end

      def sign_url(oid, verb, duration)
        # needs to be implemented in each subclass
        not_supported
      end

      def temp_path
        path = File.join(Dir.tmpdir, "temp-path-#{SecureRandom.uuid}")
        begin
          yield path if block_given?
          path
        ensure
          FileUtils.rm_f(path) if block_given?
        end
      end

      private

      def not_supported
        raise NotImplemented, 'not supported by this blobstore'
      end
    end
  end
end

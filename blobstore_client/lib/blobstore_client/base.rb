# Copyright (c) 2009-2012 VMware, Inc.

require 'tmpdir'
require 'securerandom'

module Bosh
  module Blobstore
    class BaseClient < Client

      # @param [Hash] options blobstore specific options
      def initialize(options)
        @options = Bosh::Common.symbolize_keys(options)
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
      def create(contents, id=nil)
        if contents.kind_of?(File)
          create_file(id, contents)
        else
          temp_path do |path|
            File.open(path, "w") do |file|
              file.write(contents)
            end
            return create_file(id, File.open(path, "r"))
          end
        end
      rescue BlobstoreError => e
        raise e
      rescue Exception => e
        raise BlobstoreError,
          "Failed to create object, underlying error: %s %s" %
          [e.message, e.backtrace.join("\n")]
      end

      # Get an object from the blobstore.
      # @param [String] id object id
      # @param [File] file where to store the fetched object
      # @return [String] the object contents if the file parameter is nil
      def get(id, file = nil)
        if file
          get_file(id, file)
          file.flush
        else
          result = nil
          temp_path do |path|
              File.open(path, "w") { |file| get_file(id, file) }
              result = File.open(path, "r") { |file| file.read }
          end
          result
        end
      rescue BlobstoreError => e
        raise e
      rescue Exception => e
        raise BlobstoreError,
              "Failed to create object, underlying error: %s %s" %
              [e.message, e.backtrace.join("\n")]
      end

      # @return [void]
      def delete(oid)
        delete_object(oid)
      end

      # @return [Boolean]
      def exists?(oid)
        object_exists?(oid)
      end

      protected

      def create_file(id, file)
        # needs to be implemented in each subclass
        raise "#create not implemented"
      end

      def get_file(id, file)
        # needs to be implemented in each subclass
        raise "#get not implemented"
      end

      def delete_object(oid)
        # needs to be implemented in each subclass
        raise "#delete not implemented"
      end

      def object_exists?(oid)
        # needs to be implemented in each subclass
        raise "#exists? not implemented"
      end

      def temp_path
        path = File.join(Dir::tmpdir, "temp-path-#{SecureRandom.uuid}")
        begin
          yield path if block_given?
          path
        ensure
          FileUtils.rm_f(path) if block_given?
        end
      end

    end
  end
end

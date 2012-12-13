# Copyright (c) 2009-2012 VMware, Inc.

require "tmpdir"

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
      # @overload create(contents)
      #   @param [String] contents contents to upload
      # @overload create(file)
      #   @param [File] file file to upload
      # @return [String] object id of the created blobstore object
      def create(contents)
        if contents.kind_of?(File)
          create_file(contents)
        else
          temp_path do |path|
            File.open(path, "w") do |file|
              file.write(contents)
            end
            return create_file(File.open(path, "r"))
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

      protected

      def create_file(file)
        # needs to be implemented in each subclass
      end

      def get_file(id, file)
        # needs to be implemented in each subclass
      end

      def delete_object(oid)
        # needs to be implemented in each subclass
      end

      def temp_path
        path = File.join(Dir::tmpdir, "temp-path-#{UUIDTools::UUID.random_create}")
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

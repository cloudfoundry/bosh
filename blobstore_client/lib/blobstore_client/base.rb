# Copyright (c) 2009-2012 VMware, Inc.

require "tmpdir"

module Bosh
  module Blobstore
    class BaseClient < Client

      def initialize(options)
        @options = Bosh::Common.symbolize_keys(options)
      end

      def symbolize_keys(hash)
        hash.inject({}) do |h, (key, value)|
          h[key.to_sym] = value
          h
        end
      end

      def create_file(file)

      end

      def get_file(id, file)

      end

      def create(contents)
        if contents.kind_of?(File)
          create_file(contents)
        else
          temp_path do |path|
            begin
              File.open(path, "w") do |file|
                file.write(contents)
              end
              return create_file(File.open(path, "r"))
            rescue BlobstoreError => e
              raise e
            rescue Exception => e
              raise BlobstoreError,
                "Failed to create object, underlying error: %s %s" %
                [e.message, e.backtrace.join("\n")]
            end
          end
        end
      end

      def get(id, file = nil)
        if file
          get_file(id, file)
        else
          result = nil
          temp_path do |path|
            begin
              File.open(path, "w") { |file| get_file(id, file) }
              result = File.open(path, "r") { |file| file.read }
            rescue BlobstoreError => e
              raise e
            rescue Exception => e
              raise BlobstoreError,
                "Failed to create object, underlying error: %s %s" %
                [e.message, e.backtrace.join("\n")]
            end
          end
          result
        end
      end

      protected

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

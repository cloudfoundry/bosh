require 'json'

module Bosh::Director
  module BoshSchemaCaching
    # Dump the cached schema to the filename given in Marshal format.
    def dump_schema_cache(file)
      File.open(file, 'wb'){|f| f.write(JSON.pretty_generate(@schemas) + "\n")}
      nil
    end

    # Dump the cached schema to the filename given unless the file
    # already exists.
    def dump_schema_cache?(file)
      dump_schema_cache(file) unless File.exist?(file)
    end

    # Replace the schema cache with the data from the given file, which
    # should be in Marshal format.
    def load_schema_cache(file)
      @schemas = JSON.load(File.read(file))
      nil
    end

    # Replace the schema cache with the data from the given file if the
    # file exists.
    def load_schema_cache?(file)
      load_schema_cache(file) if File.exist?(file)
    end

    def schemas
      @schemas
    end
  end

  Sequel::Database.register_extension(:bosh_schema_caching, BoshSchemaCaching)
end

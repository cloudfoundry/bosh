# module Bosh::Director
#   module SchemaCaching
#
#     def dump_schema_cache(file)
#       File.open(file, 'wb'){|f| f.write(JSON.pretty_generate(@schemas))}
#       nil
#     end
#
#     def dump_schema_cache?(file)
#       dump_schema_cache(file) unless File.exist?(file)
#     end
#
#     def load_schema_cache(file)
#       @schemas = JSON.load(File.read(file))
#       nil
#     end
#
#     def load_schema_cache?(file)
#       load_schema_cache(file) if File.exist?(file)
#     end
#   end
#
#   puts 'here 1'
#   Sequel::Database.register_extension(:bosh_schema_caching, Bosh::Director::SchemaCaching)
# end

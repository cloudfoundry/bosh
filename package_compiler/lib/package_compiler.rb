module Bosh; module PackageCompiler; end; end

require 'logger'
require 'blobstore_client'
require 'agent_client'
require 'package_compiler/compiler'

module Bosh
  module PackageCompiler
    class Runner
      class << self
        def start
          case ARGV[0]
          when "compile"
            Bosh::PackageCompiler::Compiler.new.compile
          when "apply"
            Bosh::PackageCompiler::Compiler.new.apply
          end
        end
      end
    end
  end
end

module Bosh; module PackageCompiler; end; end

require 'logger'
require 'blobstore_client'
require 'agent_client'
require 'package_compiler/compiler'

module Bosh
  module PackageCompiler
    class Runner
      class << self
        def start(options)
          Bosh::PackageCompiler::Compiler.new(options).start
        end
      end
    end
  end
end

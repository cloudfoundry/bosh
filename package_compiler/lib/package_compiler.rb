module Bosh; module PackageCompiler; end; end

require 'logger'
require 'yaml'
require 'blobstore_client'
require 'common/common'
require 'common/properties'
require 'agent_client'
require 'package_compiler/compiler'
require 'fileutils'

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

module Bosh; module Release; end; end

require 'logger'
require 'yaml'
require 'json'
require 'blobstore_client'
require 'common/common'
require 'common/properties'
require 'agent_client'
require 'bosh/release/compiler'
require 'fileutils'

module Bosh
  module Release
    class Runner
      class << self
        def start(options)
          Compiler.new(options).start
        end
      end
    end
  end
end

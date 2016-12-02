require 'spec_helper'

module Support
  module FileHelpers
    class DeploymentDirectory
      attr_reader :path, :artifacts_dir, :tarballs

      def initialize
        @path = Dir.mktmpdir('deployment-path')
      end

      def add_file(filepath, contents = nil)
        full_path = File.join(path, filepath)
        FileUtils.mkdir_p(File.dirname(full_path))

        if contents
          File.open(full_path, 'w') { |f| f.write(contents) }
        else
          FileUtils.touch(full_path)
        end

        full_path
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Support::FileHelpers)
end

require 'yaml'

module Bosh::Dev
  class RubyVersion
    class << self
      @@versions = ['2.4.2']

      def supported?(version)
        @@versions.include?(version)
      end

      def to_s
        @@versions.join(', ')
      end
    end
  end
end

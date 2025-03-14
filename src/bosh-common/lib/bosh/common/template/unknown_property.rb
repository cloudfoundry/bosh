module Bosh::Common
  module Template
    class UnknownProperty < StandardError
      attr_reader :name

      def initialize(name)
        @name = name
        super("Can't find property '#{name}'")
      end
    end
  end
end

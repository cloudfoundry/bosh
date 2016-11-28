module Bosh
  module Template
    class UnknownLink < StandardError
      def initialize(name)
        super("Can't find link '#{name}'")
      end
    end
  end
end

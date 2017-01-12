module Bosh
  module Cli
    module Template
      class UnknownLink < StandardError
        def initialize(name)
          super("Can't find link '#{name}'")
        end
      end
    end
  end
end

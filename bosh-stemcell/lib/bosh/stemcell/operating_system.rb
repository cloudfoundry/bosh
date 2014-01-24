module Bosh::Stemcell
  module OperatingSystem
    def self.for(operating_system_name)
      case operating_system_name
        when 'centos' then Centos.new
        when 'ubuntu' then Ubuntu.new
        else raise ArgumentError.new("invalid operating system: #{operating_system_name}")
      end
    end

    class Base
      attr_reader :name

      def initialize(options = {})
        @name = options.fetch(:name)
      end

      def ==(other)
        name == other.name
      end
    end

    class Centos < Base
      def initialize
        super(name: 'centos')
      end
    end

    class Ubuntu < Base
      def initialize
        super(name: 'ubuntu')
      end
    end
  end
end

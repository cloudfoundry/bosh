module Bosh::Stemcell
  module OperatingSystem
    def self.for(operating_system_name, operating_system_version = nil)
      case operating_system_name
        when 'centos' then Centos.new
        when 'ubuntu' then Ubuntu.new(operating_system_version)
        else raise ArgumentError.new("invalid operating system: #{operating_system_name}")
      end
    end

    class Base
      attr_reader :name, :version

      def initialize(options = {})
        @name = options.fetch(:name)
        @version = options.fetch(:version, nil)
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
      def initialize(version)
        super(name: 'ubuntu', version: version)
      end
    end
  end
end

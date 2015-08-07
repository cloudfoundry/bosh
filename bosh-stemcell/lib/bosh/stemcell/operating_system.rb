module Bosh::Stemcell
  module OperatingSystem

    def self.for(operating_system_name, operating_system_version = nil)
      case operating_system_name
        when 'centos' then Centos.new(operating_system_version)
        when 'rhel' then Rhel.new(operating_system_version)
        when 'ubuntu' then Ubuntu.new(operating_system_version)
        when 'photon' then Photon.new(operating_system_version)
        else raise ArgumentError.new("invalid operating system: #{operating_system_name}")
      end
    end

    class Base
      attr_reader :name, :version

      def initialize(options = {})
        @name = options.fetch(:name)
        @version = options.fetch(:version)
      end

      def ==(other)
        name == other.name
      end
    end

    class Rhel < Base
      def initialize(version)
        super(name: 'rhel', version: version)
      end
    end

    class Centos < Base
      def initialize(version)
        super(name: 'centos', version: version)
      end
    end
    
   class Ubuntu < Base
     def initialize(version)
       super(name: 'ubuntu', version: version)
     end
   end
    
    class Photon < Base
      def initialize(version)
        super(name: 'photon', version: version)
      end
    end
  end
end

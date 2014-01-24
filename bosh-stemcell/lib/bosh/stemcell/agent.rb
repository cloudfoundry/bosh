module Bosh::Stemcell
  module Agent
    def self.for(name)
      case name
        when 'go'
          Go.new
        when 'ruby'
          Ruby.new
        else
          raise ArgumentError.new("invalid agent: #{name}")
      end

    end

    class Go
      def name
        'go'
      end

      def ==(other)
        name == other.name
      end
    end

    class Ruby
      def name
        'ruby'
      end

      def ==(other)
        name == other.name
      end
    end
  end
end


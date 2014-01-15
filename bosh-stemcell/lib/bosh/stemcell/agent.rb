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
    end

    class Ruby
    end
  end
end


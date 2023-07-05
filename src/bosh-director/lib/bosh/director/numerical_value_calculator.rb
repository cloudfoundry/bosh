module Bosh::Director
  class NumericalValueCalculator
    def self.get_numerical_value(value, size)
      case value
      when /^\d+%$/
        [((/\d+/.match(value)[0].to_i * size) / 100).round, size].min
      when /\A[-+]?[0-9]+\z/
        value.to_i
      else
        raise 'cannot be calculated'
      end
    end
  end
end

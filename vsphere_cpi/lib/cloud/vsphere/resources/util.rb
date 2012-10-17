# Copyright (c) 2009-2012 VMware, Inc.

module VSphereCloud
  class Resources

    # Resources common utility class.
    class Util
      class << self

        # Returns the average value from a given CSV string.
        #
        # @param [String] csv CSV string of integers/floats.
        # @return [Numeric] average value
        def average_csv(csv)
          values = csv.split(",")
          result = 0
          return result if values.empty?
          values.each { |v| result += v.to_f }
          result / values.size
        end

        # Returns a random item from the given list distributed based on the
        # provided weight.
        #
        # @param [Array] list array of tuples containing the item and weight.
        # @return [Object] random item based on provided weight.
        def weighted_random(list)
          return nil if list.empty?

          weight_sum = list.inject(0) { |sum, x| sum + x[1] }
          index = rand(weight_sum)
          offset = 0
          list.each do |el, weight|
            offset += weight
            return el if index < offset
          end

          # Should never happen
          raise ArgumentError, "index: #{index} sum: #{weight_sum}"
        end
      end
    end
  end
end

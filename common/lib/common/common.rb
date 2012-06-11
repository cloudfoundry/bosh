# Copyright (c) 2012 VMware, Inc.

module Bosh

  # Class for common methods in BOSH
  module Common

    # Converts all keys of a [Hash] to symbols. Performs deep conversion.
    #
    # @param [Hash] hash to convert
    # @return [Hash] a copy of the original hash
    def symbolize_keys(hash)
      hash.inject({}) do |h, (key, value)|
        h[key.to_sym] = value.is_a?(Hash) ? symbolize_keys(value) : value
        h
      end
    end

    module_function :symbolize_keys
  end
end

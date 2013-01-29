# Copyright (c) 2012 VMware, Inc.

module Bosh

  # Module for common methods used throughout the BOSH code.
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

    # @overload which(program, path)
    #   Looks for program in the executables search path (PATH).
    #   The file must be executable to be found.
    #   @param [String] program
    #   @param [String] path search path
    #   @return [String] full path of the executable,
    #     or nil if not found
    # @overload which(programs, path)
    #   Looks for one of the programs in the executables search path (PATH).
    #   The file must be executable to be found.
    #   @param [Array] programs
    #   @param [String] path search path
    #   @return [String] full path of the executable,
    #     or nil if not found
    def which(programs, path=ENV["PATH"])
      path.split(File::PATH_SEPARATOR).each do |dir|
        Array(programs).each do |bin|
          exe = File.join(dir, bin)
          return exe if File.executable?(exe)
        end
      end
      nil
    end

    module_function :which
  end
end

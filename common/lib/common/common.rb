# Copyright (c) 2009-2012 VMware, Inc.

module Bosh

  # Class for common methods used throughout the BOSH code.
  module Common

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
        [programs].flatten.each do |bin|
          exe = File.join(dir, bin)
          return exe if File.executable?(exe)
        end
      end
      nil
    end

    module_function :which
  end
end

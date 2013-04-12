module Bosh
  module Agent
    class NullLogger < Logger
      def initialize
      end

      def add(level, message)
        # do nothing
      end
    end

    class SigarBox
      def self.create_sigar
        sigar = nil
        begin
          GC.disable
          sigar = Sigar.new
          sigar.logger = NullLogger.new
        ensure
          GC.enable
        end
        sigar
      end
    end
  end
end
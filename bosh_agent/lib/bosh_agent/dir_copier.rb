module Bosh
  module Agent
    class DirCopier
      def initialize(source, destination)
        @source = source
        @destination = destination
      end

      def copy
        `(cd #{@source} && tar cf - .) | (cd #{@destination} && tar xpf -)`
      end
    end
  end
end

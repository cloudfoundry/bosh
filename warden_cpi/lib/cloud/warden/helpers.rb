module Bosh::WardenCloud
  module Helpers

    class SecureRandom
      def self.uuid
        File.open('/dev/urandom') { |x| x.read(16).unpack('H*')[0] }
      end
    end

  end
end

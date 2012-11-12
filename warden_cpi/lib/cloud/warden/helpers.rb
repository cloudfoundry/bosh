module Bosh::WardenCloud
  module Helpers

    def secure_uuid
      File.open('/dev/urandom') { |x| x.read(16).unpack('H*')[0] }
    end
  end
end

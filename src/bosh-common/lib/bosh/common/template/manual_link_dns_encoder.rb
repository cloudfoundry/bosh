module Bosh::Common
  module Template
    class ManualLinkDnsEncoder
      def initialize(manual_link_address)
        @manual_link_address = manual_link_address
      end

      def encode_query(*_)
        @manual_link_address
      end
    end
  end
end

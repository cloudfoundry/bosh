module Bosh
  module Cli
    class CloudConfig < Struct.new(:properties, :created_at)
      def initialize(attrs)
        self.properties = attrs.fetch(:properties)
        self.created_at = attrs.fetch(:created_at)
      end
    end
  end
end

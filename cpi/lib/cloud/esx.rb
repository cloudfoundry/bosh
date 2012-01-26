autoload :EsxCloud, "director/cloud/esx/cloud"

module Bosh

  module Clouds

    class Esx
      extend Forwardable

      def_delegators :@delegate, :create_stemcell, :delete_stemcell, :create_vm, :delete_vm, :configure_networks,
                                 :attach_disk, :detach_disk, :create_disk, :delete_disk, :validate_deployment

      def initialize(options)
        @delegate = EsxCloud::Cloud.new(options)
      end

    end

  end

end

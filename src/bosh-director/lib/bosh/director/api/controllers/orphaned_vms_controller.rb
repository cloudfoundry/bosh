require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class OrphanedVmsController < BaseController
      def initialize(config)
        super(config)
      end

      get '/' do
        content_type(:json)

        elements = Models::OrphanedVm.all.map do |vm|
          {
            'az' => vm.availability_zone,
            'cid' => vm.cid,
            'deployment_name' => vm.deployment_name,
            'instance_name' => vm.instance_name,
            'ip_addresses' => vm.ip_addresses.map(&:address),
            'orphaned_at' => vm.orphaned_at.to_s,
          }
        end

        json_encode(elements)
      end
    end
  end
end

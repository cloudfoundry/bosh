require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class OrphanedVmsController < BaseController
      def initialize(config)
        super(config)
      end

      get '/' do
        content_type(:json)

        elements = Models::OrphanedVm.list_all

        json_encode(elements)
      end
    end
  end
end

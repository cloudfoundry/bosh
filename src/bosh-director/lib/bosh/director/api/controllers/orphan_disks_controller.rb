require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class OrphanDisksController < BaseController
      get '/' do
        content_type(:json)
        orphan_json = OrphanDiskManager.new(@logger).list_orphan_disks
        json_encode(orphan_json)
      end
    end
  end
end

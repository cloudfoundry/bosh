require 'bosh/director/api/controllers/base_controller'
require 'bosh/director/compiled_packages_exporter'

module Bosh::Director
  module Api::Controllers
    class CompiledPackagesController < BaseController
      get '/stemcells/:stemcell_name/:stemcell_version/releases/:release_name/:release_version/compiled_packages' do
        exporter = CompiledPackagesExporter.new
        send_file exporter.tgz_path, type: :tgz
      end
    end
  end
end

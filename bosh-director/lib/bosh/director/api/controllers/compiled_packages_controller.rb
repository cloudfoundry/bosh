require 'bosh/director/api/controllers/base_controller'
require 'tempfile'

module Bosh::Director::Api::Controllers
  class CompiledPackagesController < BaseController
    get '/stemcells/:stemcell_name/:stemcell_version/releases/:release_name/:release_version/compiled_packages' do
      tgz = Tempfile.new('fake.tgz')
      send_file tgz.path, type: :tgz
    end
  end
end

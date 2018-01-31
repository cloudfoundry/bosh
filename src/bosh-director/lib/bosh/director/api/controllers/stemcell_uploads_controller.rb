require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class StemcellUploadsController < BaseController
      post '/', scope: :read_stemcells do
        payload = json_decode(request.body.read)

        stemcell = payload['stemcell']
        raise ValidationMissingField, "Missing 'stemcell' field" if stemcell.nil?

        name = stemcell['name']
        raise ValidationMissingField, "Missing 'name' field" if name.nil?

        version = stemcell['version']
        raise ValidationMissingField, "Missing 'version' field" if version.nil?

        found_cpis = Bosh::Director::Models::StemcellUpload.where(name: name, version: version).all.map(&:cpi)

        cpi_config_names = CloudFactory.create_with_latest_configs.all_names

        result = { 'needed' => !(cpi_config_names - found_cpis).empty? }
        json_encode(result)
      end
    end
  end
end

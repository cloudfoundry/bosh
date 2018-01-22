require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class StemcellMatchesController < BaseController
      post '/', scope: :read_stemcells do
        payload = json_decode(request.body.read)

        missing_stemcells = []

        payload.each do |record|
          name = record['name']
          if name.nil?
            raise ValidationMissingField, "Missing 'name' field"
          end

          version = record['version']
          if version.nil?
            raise ValidationMissingField, "Missing 'version' field"
          end

          found_cpis = @stemcell_manager.all_by_name_and_version(name, version).map(&:cpi)
          found_cpis += Bosh::Director::Models::StemcellMatch.where(name: name, version: version).all.map(&:cpi)

          cpi_config_names = CloudFactory.create_with_latest_configs.all_names

          if (cpi_config_names - found_cpis).length > 0
            missing_stemcells << {
              'name' => name,
              'version' => version,
            }
          end
        end

        result = { 'missing' => missing_stemcells }
        json_encode(result)
      end
    end
  end
end

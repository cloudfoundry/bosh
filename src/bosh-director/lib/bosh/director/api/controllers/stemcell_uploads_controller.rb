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

        result = { 'needed' => stemcell_not_found?(name, version) }
        json_encode(result)
      end

      def stemcell_not_found?(name, version)
        found_cpis = Bosh::Director::Models::StemcellUpload.where(name: name, version: version).all.map(&:cpi)
        cloud_factory = CloudFactory.create
        cloud_factory.all_names.each do |cpi_name|
          matched = found_cpis & cloud_factory.get_cpi_aliases(cpi_name)
          return true if matched.empty?
        end

        false
      end
    end
  end
end

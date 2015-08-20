require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class PackagesController < BaseController
      post '/matches', :consumes => :yaml do
        manifest = Psych.load(request.body)

        unless manifest.is_a?(Hash) && manifest['packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprint_list = []

        manifest['packages'].each do |package|
          fingerprint_list << package['fingerprint'] if package['fingerprint']
        end

        matching_packages = Models::Package.where(fingerprint: fingerprint_list, ~:sha1 => nil, ~:blobstore_id => nil).all

        json_encode(matching_packages.map(&:fingerprint).compact.uniq)
      end

      post '/matches_compiled', :consumes => :yaml do
        manifest = Psych.load(request.body)

        unless manifest.is_a?(Hash) && manifest['compiled_packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprint_list = []

        manifest['compiled_packages'].each do |package|
          fingerprint_list << package['fingerprint'] if package['fingerprint']
        end

        matching_packages = Models::Package.join(Models::CompiledPackage, :package_id=>:id).where(fingerprint: fingerprint_list).all

        json_encode(matching_packages.map(&:fingerprint).compact.uniq)
      end
    end
  end
end

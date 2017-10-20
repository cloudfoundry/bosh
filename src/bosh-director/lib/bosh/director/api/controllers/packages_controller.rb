require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class PackagesController < BaseController
      post '/matches', :consumes => :yaml do
        manifest = YAML.load(request.body.read)

        unless manifest.is_a?(Hash) && manifest['packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprint_list = []

        manifest['packages'].each do |package|
          fingerprint_list << package['fingerprint'] if package['fingerprint']
        end

        matching_packages = Models::Package.where(Sequel.~(:sha1 => nil), Sequel.~(:blobstore_id => nil), fingerprint: fingerprint_list).all

        json_encode(matching_packages.map(&:fingerprint).compact.uniq)
      end

      post '/matches_compiled', :consumes => :yaml do
        manifest = YAML.load(request.body.read)

        unless manifest.is_a?(Hash) && manifest['compiled_packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprint_list = []
        manifest['compiled_packages'].each do |package|
          fingerprint_list << package['fingerprint'] if package['fingerprint']
        end

        matching_packages = Models::Package.join(Models::CompiledPackage, :package_id=>:id)
                              .select(:packages__name, :packages__fingerprint, :compiled_packages__dependency_key, :stemcell_os, :stemcell_version)
                              .where(fingerprint: fingerprint_list).all

        matching_packages = filter_matching_packages(matching_packages, manifest)

        json_encode(matching_packages.map(&:fingerprint).compact.uniq)
      end

      # dependencies & stemcell should also match
      def filter_matching_packages(matching_packages, manifest)
        compiled_release_manifest = CompiledRelease::Manifest.new(manifest)
        filtered_packages = []
        matching_packages.each do |package|
          if compiled_release_manifest.has_matching_package(package.name, package[:stemcell_os], package[:stemcell_version], package[:dependency_key])
            filtered_packages << package
          end
        end
        filtered_packages
      end
    end
  end
end

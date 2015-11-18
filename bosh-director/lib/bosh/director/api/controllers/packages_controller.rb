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

        matching_packages = Models::Package.join(Models::CompiledPackage, :package_id=>:id)
                                .select(:packages__name, :packages__fingerprint, :compiled_packages__dependency_key, :stemcells__operating_system, :stemcells__version)
                                .join(Models::Stemcell, :id=>:stemcell_id)
                                .where(fingerprint: fingerprint_list).all

        matching_packages = filter_matching_packages(matching_packages, manifest)

        json_encode(matching_packages.map(&:fingerprint).compact.uniq)
      end

      # dependencies & stemcell should also match
      def filter_matching_packages(matching_packages, manifest)
        filtered_packages = []

        matching_packages.each do |package|
          stemcell_match = "#{package[:operating_system]}/#{package[:version]}" == compiled_package_meta(package.name, manifest)['stemcell']
          dependencies_match = package[:dependency_key] == dependency_key(package, manifest)

          if stemcell_match && dependencies_match
            filtered_packages << package
          end
        end

        filtered_packages
      end

      def dependency_key(package, manifest)
        compiled_package_meta = compiled_package_meta(package.name, manifest)
        dependencies = transitive_dependencies(compiled_package_meta, manifest)

        key = dependencies.to_a.sort_by {|k| k["name"]}.map { |p| [p['name'], p['version']]}
        Yajl::Encoder.encode(key)
      end

      def transitive_dependencies(compiled_package_meta, manifest)
        dependencies = Set.new
        return dependencies if compiled_package_meta['dependencies'].nil?

        compiled_package_meta['dependencies'].each do |dependency_package_name|
          dependency_compiled_package_meta = compiled_package_meta(dependency_package_name, manifest)
          dependencies << dependency_compiled_package_meta
          dependencies.merge(transitive_dependencies(dependency_compiled_package_meta, manifest))
        end

        dependencies
      end

      def compiled_package_meta(package_name, manifest)
        manifest['compiled_packages'].select { |p| p['name'] == package_name}[0]
      end

    end
  end
end

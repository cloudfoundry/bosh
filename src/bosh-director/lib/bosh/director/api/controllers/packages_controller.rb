require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class PackagesController < BaseController
      post '/matches', :consumes => :yaml do
        manifest = YAML.load(request.body.read, aliases: true)

        unless manifest.is_a?(Hash) && manifest['packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprint_list = []

        manifest['packages'].each do |package|
          fingerprint_list << package['fingerprint'] if package['fingerprint']
        end

        matching_packages = []

        unless existing_release_version_dirty?(manifest)
          matching_packages = Models::Package.where(fingerprint: fingerprint_list)
                                             .where(Sequel.~(sha1: nil))
                                             .where(Sequel.~(blobstore_id: nil)).all
        end

        json_encode(matching_packages.map(&:fingerprint).compact.uniq)
      end

      post '/matches_compiled', :consumes => :yaml do
        manifest = YAML.load(request.body.read, aliases: true)

        unless manifest.is_a?(Hash) && manifest['compiled_packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprints = []

        unless existing_release_version_dirty?(manifest)
          fingerprints = fingerprints_that_do_not_need_to_be_uploaded(manifest)
        end

        json_encode(fingerprints)
      end

      private

      def fingerprints_that_do_not_need_to_be_uploaded(manifest_yaml)
        manifest_fingerprints = manifest_yaml['compiled_packages'].map { |package| package['fingerprint'] }.compact

        existing_packages =
          Models::Package.join('compiled_packages', package_id: :id)
            .select(Sequel.qualify('packages', 'name'),
                    Sequel.qualify('packages', 'fingerprint'),
                    Sequel.qualify('compiled_packages', 'dependency_key'),
                    :stemcell_os,
                    :stemcell_version)
            .where(fingerprint: manifest_fingerprints).all

        filtered_packages = filter_matching_packages(existing_packages, manifest_yaml)
        filtered_packages.map(&:fingerprint).compact.uniq
      end

      # dependencies & stemcell should also match
      def filter_matching_packages(existing_packages, manifest_yaml)
        compiled_release_manifest = CompiledRelease::Manifest.new(manifest_yaml)

        # Remove packages that were not matched, but have identical fingerprints to ones that were matched
        # This step is needed to prevent the cli from filtering compiled packages that have a matching fingerprint already
        # but not the exact compiled package with an identical name too
        unmatched_package_fingerprints = fingerprints_not_matching_packages(existing_packages, compiled_release_manifest)

        filtered_packages =
          existing_packages.select do |package|
            compiled_release_manifest.has_matching_package(package.name, package[:stemcell_os], package[:stemcell_version],
                                                           package[:dependency_key]) &&
              !unmatched_package_fingerprints.include?(package.fingerprint)
          end

        filtered_packages
      end

      def fingerprints_not_matching_packages(existing_packages, compiled_release_manifest)
        missing_compiled_packages = compiled_release_manifest.compiled_packages.reject do |manifest_package|
          existing_packages.any? do |package|
            package[:name] == manifest_package['name'] &&
              package[:fingerprint] == manifest_package['fingerprint']
          end
        end
        missing_compiled_packages.map { |package| package['fingerprint'] }
      end

      def existing_release_version_dirty?(manifest)
        release = Models::Release.first(name: manifest['name'])
        release_version = Models::ReleaseVersion.first(release_id: release&.id, version: manifest['version'])

        release_version && !release_version.update_completed
      end
    end
  end
end

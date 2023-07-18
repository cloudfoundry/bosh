require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class PackagesController < BaseController
      post '/matches', consumes: :yaml do
        manifest_hash = YAML.load(request.body.read, aliases: true)

        unless manifest_hash.is_a?(Hash) && manifest_hash['packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprints =
          if existing_release_version_dirty?(manifest_hash)
            []
          else
            fingerprint_list = manifest_hash['packages'].map { |package| package['fingerprint'] }.compact
            Models::Package.where(fingerprint: fingerprint_list)
              .where(Sequel.~(sha1: nil))
              .where(Sequel.~(blobstore_id: nil)).all
              .map(&:fingerprint).compact.uniq
          end

        json_encode(fingerprints)
      end

      post '/matches_compiled', consumes: :yaml do
        manifest_hash = YAML.load(request.body.read, aliases: true)

        unless manifest_hash.is_a?(Hash) && manifest_hash['compiled_packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fingerprints =
          if existing_release_version_dirty?(manifest_hash)
            []
          else
            compiled_package_fingerprints_not_to_be_uploaded(manifest_hash)
          end

        json_encode(fingerprints)
      end

      private

      def compiled_package_fingerprints_not_to_be_uploaded(manifest_hash)
        compiled_release_manifest = CompiledRelease::Manifest.new(manifest_hash)

        existing_package_hashes = get_existing_package_hashes(compiled_release_manifest)
        compiled_package_hashes = get_compiled_package_hashes(compiled_release_manifest)

        # Remove packages that were not matched, but have identical fingerprints to ones that were matched
        # This step is needed to prevent the cli from filtering compiled packages that have a matching fingerprint already
        # but not the exact compiled package with an identical name too
        package_hashes_that_need_upload = compiled_package_hashes - existing_package_hashes

        package_hashes_that_are_already_uploaded = existing_package_hashes & compiled_package_hashes

        fingerprints_that_need_upload = package_hashes_that_need_upload.map { |h| h[:fingerprint] }.compact.uniq
        fingerprints_that_are_already_uploaded = package_hashes_that_are_already_uploaded.map { |h| h[:fingerprint] }.compact.uniq

        fingerprints_that_are_already_uploaded - fingerprints_that_need_upload
      end

      def get_existing_package_hashes(compiled_release_manifest)
        manifest_fingerprints = compiled_release_manifest.compiled_packages.map { |package| package['fingerprint'] }.compact

        existing_packages =
          Models::Package.join('compiled_packages', package_id: :id)
            .select(Sequel.qualify('packages', 'name'),
                    Sequel.qualify('packages', 'fingerprint'),
                    Sequel.qualify('compiled_packages', 'dependency_key'),
                    :stemcell_os,
                    :stemcell_version)
            .where(fingerprint: manifest_fingerprints).all

        existing_packages.map do |package|
          {
            name: package.name,
            fingerprint: package[:fingerprint],
            stemcell: "#{package[:stemcell_os]}/#{package[:stemcell_version]}",
            dependency_key: package[:dependency_key],
          }
        end
      end

      def get_compiled_package_hashes(compiled_release_manifest)
        compiled_release_manifest.compiled_packages.map do |package|
          {
            name: package['name'],
            fingerprint: package['fingerprint'],
            stemcell: package['stemcell'],
            dependency_key: compiled_release_manifest.dependency_key(package['name']),
          }
        end
      end

      def existing_release_version_dirty?(manifest_hash)
        release = Models::Release.first(name: manifest_hash['name'])
        release_version = Models::ReleaseVersion.first(release_id: release&.id, version: manifest_hash['version'])

        release_version && !release_version.update_completed
      end
    end
  end
end

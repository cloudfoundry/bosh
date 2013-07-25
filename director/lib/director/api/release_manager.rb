# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ReleaseManager
      include ApiHelper

      RELEASE_TGZ = "release.tgz"

      # Finds release by name
      # @param [String] name Release name
      # @return [Models::Release]
      # @raise [ReleaseNotFound]
      def find_by_name(name)
        release = Models::Release[:name => name]
        if release.nil?
          raise ReleaseNotFound, "Release `#{name}' doesn't exist"
        end
        release
      end

      # @param [Models::Release] release Release model
      # @param [String] version Release version
      # @return [Models::ReleaseVersion] Release version model
      # @raise [ReleaseVersionNotFound]
      def find_version(release, version)
        dataset = release.versions_dataset
        release_version = dataset.filter(:version => version).first
        if release_version.nil?
          raise ReleaseVersionNotFound,
                "Release version `#{release.name}/#{version}' doesn't exist"
        end

        release_version
      end

      def create_release(user, release_bundle, options = {})
        release_dir = Dir.mktmpdir("release")

        if options['remote']
          options['location'] = release_bundle
        else
          unless check_available_disk_space(release_dir, release_bundle.size)
            raise NotEnoughDiskSpace, "Uploading release archive failed. " +
              "Insufficient space on BOSH director in #{release_dir}"
          end
  
          write_file(File.join(release_dir, RELEASE_TGZ), release_bundle)
        end

        JobQueue.new.enqueue(user, Jobs::UpdateRelease, 'create release', [release_dir, options])
      end

      def delete_release(user, release, options = {})
        JobQueue.new.enqueue(user, Jobs::DeleteRelease, "delete release: #{release.name}", [release.name, options])
      end
    end
  end
end
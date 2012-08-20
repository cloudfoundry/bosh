# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ReleaseManager
      include ApiHelper
      include TaskHelper

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
        release_tgz = File.join(release_dir, RELEASE_TGZ)

        write_file(release_tgz, release_bundle)
        task = create_task(user, :update_release, "create release")
        Resque.enqueue(Jobs::UpdateRelease, task.id, release_dir, options)
        task
      end

      def delete_release(user, release, options = {})
        task = create_task(user, :delete_release,
                           "delete release: #{release.name}")
        Resque.enqueue(Jobs::DeleteRelease, task.id, release.name, options)
        task
      end
    end
  end
end
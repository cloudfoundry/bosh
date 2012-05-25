# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  module Api
    class ReleaseManager
      include ApiHelper
      include TaskHelper

      RELEASE_TGZ = "release.tgz"

      def create_release(user, release_bundle)
        release_dir = Dir.mktmpdir("release")
        release_tgz = File.join(release_dir, RELEASE_TGZ)

        write_file(release_tgz, release_bundle)
        task = create_task(user, :update_release, "create release")
        Resque.enqueue(Jobs::UpdateRelease, task.id, release_dir)
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
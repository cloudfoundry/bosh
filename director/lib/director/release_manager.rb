module Bosh::Director

  class ReleaseManager
    include TaskHelper

    RELEASE_TGZ = "release.tgz"

    def create_release(user, release_bundle)
      release_dir = Dir.mktmpdir("release")
      release_tgz = File.join(release_dir, RELEASE_TGZ)
      File.open(release_tgz, "w") do |f|
        buffer = ""
        f.write(buffer) until release_bundle.read(16384, buffer).nil?
      end

      task = create_task(user, "create release")
      Resque.enqueue(Jobs::UpdateRelease, task.id, release_dir)
      task
    end

    def delete_release(user, release, options = {})
      task = create_task(user, "delete release: #{release.name}")
      Resque.enqueue(Jobs::DeleteRelease, task.id, release.name, options)
      task
    end

  end
end
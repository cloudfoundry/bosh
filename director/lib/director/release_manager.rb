module Bosh::Director

  class ReleaseManager

    RELEASE_TGZ = "release.tgz"

    def create_release(release_bundle)
      release_dir = Dir.mktmpdir("release")
      release_tgz = File.join(release_dir, RELEASE_TGZ)
      File.open(release_tgz, "w") do |f|
        buffer = ""
        f.write(buffer) until release_bundle.read(16384, buffer).nil?
      end

      task = Models::Task.new(:state => :queued, :timestamp => Time.now.to_i)
      task.create

      Resque.enqueue(Jobs::UpdateRelease, task.id, release_dir)

      task
    end

  end
end
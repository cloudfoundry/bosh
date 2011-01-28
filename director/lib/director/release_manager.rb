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

      task_status_file = File.join(Config.base_dir, "tasks", task.id.to_s)
      FileUtils.mkdir_p(File.dirname(task_status_file))
      logger = Logger.new(task_status_file)
      logger.level= Config.logger.level
      logger.info("Enqueuing task: #{task.id}")

      task.output = task_status_file
      task.save!

      Resque.enqueue(Jobs::UpdateRelease, task.id, release_dir)

      task
    end

    def delete_release(release, options = {})
      task = Models::Task.new(:state => :queued, :timestamp => Time.now.to_i)
      task.create

      task_status_file = File.join(Config.base_dir, "tasks", task.id.to_s)
      FileUtils.mkdir_p(File.dirname(task_status_file))
      logger = Logger.new(task_status_file)
      logger.level= Config.logger.level
      logger.info("Enqueuing task: #{task.id}")

      task.output = task_status_file
      task.save!

      Resque.enqueue(Jobs::DeleteRelease, task.id, release.name, options)

      task
    end

  end
end
module Bosh::Director

  class StemcellManager

    def create_stemcell(stemcell)
      stemcell_file = Tempfile.new("stemcell")
      File.open(stemcell_file.path, "w") do |f|
        buffer = ""
        f.write(buffer) until stemcell.read(16384, buffer).nil?
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

      Resque.enqueue(Jobs::UpdateStemcell, task.id, stemcell_file.path)

      task
    end

  end
end

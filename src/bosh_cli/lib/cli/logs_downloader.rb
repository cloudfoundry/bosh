module Bosh::Cli
  class LogsDownloader
    def initialize(director, ui)
      @director = director
      @ui = ui
    end

    def build_destination_path(job_name, job_index_or_id, directory)
      time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
      File.join(directory, "#{job_name}.#{job_index_or_id}.#{time}.tgz")
    end

    def download(resource_id, logs_destination_path)
      @ui.say("Downloading log bundle (#{resource_id.to_s.make_green})...")
      @ui.nl

      begin
        tmp_file = @director.download_resource(resource_id)

        FileUtils.mv(tmp_file, logs_destination_path)

        @ui.say("Logs saved in '#{logs_destination_path.make_green}'")
        @ui.nl

      rescue Bosh::Cli::DirectorError => e
        @ui.err("Unable to download logs from director: #{e}")

      ensure
        FileUtils.rm_rf(tmp_file) if tmp_file
      end
    end
  end
end

module Bosh::Cli
  class LogsDownloader
    def initialize(director, ui)
      @director = director
      @ui = ui
    end

    def build_destination_path(deployment_name, job_name, job_index_or_id, directory)
      time = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
      file_name = deployment_name
      if job_name != '*'
        file_name += ".#{job_name}"
        file_name += ".#{job_index_or_id}" unless job_index_or_id == "*"
      end
      File.join(directory, "#{file_name}.#{time}.tgz")
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

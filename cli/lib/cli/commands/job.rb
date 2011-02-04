module Bosh::Cli::Command
  class Job < Base

    def generate(name)
      check_if_release_dir

      if !name.bosh_valid_id?
        err "`#{name}' is not a vaild Bosh id"
      end

      job_dir = File.join("jobs", name)

      if File.exists?(job_dir)
        err "Job `#{name}' already exists, please pick another name"
      end

      say "create\t#{job_dir}"
      FileUtils.mkdir_p(job_dir)

      config_dir = File.join(job_dir, "config")
      say "create\t#{config_dir}"
      FileUtils.mkdir_p(config_dir)

      spec_file = File.join(job_dir, "spec")
      say "create\t#{spec_file}"
      FileUtils.touch(spec_file)

      monit_file = File.join(job_dir, "monit")
      say "create\t#{monit_file}"
      FileUtils.touch(monit_file)

      File.open(spec_file, "w") do |f|
        f.write("---\nname: #{name}\n\nconfiguration:\n\npackages:\n")
      end

      say "\nGenerated skeleton for `#{name}' job in `#{job_dir}'"
    end

  end
end

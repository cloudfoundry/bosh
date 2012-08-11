# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Job < Base

    # usage "generate job <name>"
    # desc  "Generate job template"
    # route :job, :generate
    def generate(name)
      check_if_release_dir

      unless name.bosh_valid_id?
        err("`#{name}' is not a vaild BOSH id")
      end

      job_dir = File.join("jobs", name)

      if File.exists?(job_dir)
        err("Job `#{name}' already exists, please pick another name")
      end

      say("create\t#{job_dir}")
      FileUtils.mkdir_p(job_dir)

      templates_dir = File.join(job_dir, "templates")
      say("create\t#{templates_dir}")
      FileUtils.mkdir_p(templates_dir)

      spec_file = File.join(job_dir, "spec")
      say("create\t#{spec_file}")
      FileUtils.touch(spec_file)

      monit_file = File.join(job_dir, "monit")
      say("create\t#{monit_file}")
      FileUtils.touch(monit_file)

      File.open(spec_file, "w") do |f|
        f.write("---\nname: #{name}\ntemplates:\n\npackages:\n")
      end

      say("\nGenerated skeleton for `#{name}' job in `#{job_dir}'")
    end

  end
end

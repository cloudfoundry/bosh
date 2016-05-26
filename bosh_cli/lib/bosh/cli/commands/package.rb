# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Package < Base

    usage "generate package"
    desc "Generate package template"
    def generate(name)
      check_if_release_dir

      unless name.bosh_valid_id?
        err("'#{name}' is not a vaild BOSH id")
      end

      package_dir = File.join("packages", name)

      if File.exists?(package_dir)
        err("Package '#{name}' already exists, please pick another name")
      end

      say("create\t#{package_dir}")
      FileUtils.mkdir_p(package_dir)

      generate_file(package_dir, "packaging") do
        "# abort script on any command that exits " +
        "with a non zero value\nset -e\n"
      end

      generate_file(package_dir, "pre_packaging") do
        "# abort script on any command that exits " +
        "with a non zero value\nset -e\n"
      end

      generate_file(package_dir, "spec") do
        "---\nname: #{name}\n\ndependencies:\n\nfiles:\n"
      end

      say("\nGenerated skeleton for '#{name}' package in '#{package_dir}'")
    end

    private

    def generate_file(dir, file)
      path = File.join(dir, file)
      say("create\t#{path}")
      FileUtils.touch(path)
      File.open(path, "w") do |f|
        f.write(yield)
      end
    end

  end
end

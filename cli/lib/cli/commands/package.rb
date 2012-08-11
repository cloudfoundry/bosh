# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Package < Base

    def create_all
      specs_glob = File.join(work_dir, "packages", "*", "spec")

      Dir[specs_glob].each do |spec|
        create(spec)
      end
    end

    # usage "create package <name>|<path>"
    # desc  "Build a single package"
    # route :package, :create
    def create(name_or_path)
      if name_or_path == "--all"
        redirect(:package, :create_all)
      end

      spec = read_spec(name_or_path)

      unless spec.is_a?(Hash) && spec.has_key?("name") && spec.has_key?("files")
        err("Sorry, '#{name_or_path}' doesn't look like a valid package spec")
      end

      package_name = spec["name"]
      header("Found '#{package_name}' spec")
      print_spec(spec)
      header("Building package...")

      builder = Bosh::Cli::PackageBuilder.new(spec, work_dir,
                                              false, release.blobstore)
      builder.build
      builder
    end

    # usage "generate package <name>"
    # desc  "Generate package template"
    # route :package, :generate
    def generate(name)
      check_if_release_dir

      unless name.bosh_valid_id?
        err("`#{name}' is not a vaild BOSH id")
      end

      package_dir = File.join("packages", name)

      if File.exists?(package_dir)
        err("Package `#{name}' already exists, please pick another name")
      end

      say("create\t#{package_dir}")
      FileUtils.mkdir_p(package_dir)

      generate_file(package_dir, "packaging") do
        "# abort script on any command that exit with a non zero value\nset -e\n"
      end

      generate_file(package_dir, "pre_packaging") do
        "# abort script on any command that exit with a non zero value\nset -e\n"
      end

      generate_file(package_dir, "spec") do
        "---\nname: #{name}\n\ndependencies:\n\nfiles:\n"
      end

      say("\nGenerated skeleton for `#{name}' package in `#{package_dir}'")
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

    def print_spec(spec)
      say("Package name: #{spec["name"]}")
      say("Files:")
      for file in spec["files"]
        say("  - #{file}")
      end
    end

    def read_spec(name)
      load_yaml_file(find_spec(name))
    end

    def find_spec(name)
      if File.directory?(name)
        spec_path = File.join(name, "spec")
        if File.exists?(spec_path)
          spec_path
        else
          err("Cannot find spec file in '#{name}' directory")
        end
      elsif File.file?(name)
        name
      else
        package_dir = File.join(work_dir, "packages", name)
        if File.directory?(package_dir)
          find_spec(package_dir)
        else
          err("Cannot find package '#{name}' (tried '#{package_dir}')")
        end

      end
    end

  end
end

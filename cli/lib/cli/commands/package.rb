module Bosh::Cli::Command
  class Package < Base

    def create_all
      specs_glob = File.join(work_dir, "packages", "*", "spec")

      Dir[specs_glob].each do |spec|
        create(spec)
      end
    end 

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

      builder = Bosh::Cli::PackageBuilder.new(spec, work_dir)
      builder.build
      builder
    end

    private

    def print_spec(spec)
      say "Package name: %s" % [ spec["name"] ]
      say "Files:"
      for file in spec["files"]
        say("  - #{file}")
      end
    end

    def read_spec(name)
      YAML.load_file(find_spec(name))
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

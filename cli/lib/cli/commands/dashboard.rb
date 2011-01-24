module Bosh::Cli::Command
  class Dashboard < Base

    def version
      say("Bosh %s" % [ Bosh::Cli::VERSION ])
    end

    def status
      say("Target:     %s" % [ target || "not set" ])
      say("User:       %s" % [ logged_in? ? username : "not set" ])
      say("Deployment: %s" % [ deployment || "not set" ])

      if in_release_dir?
        header("You are in release directory")
        release = Bosh::Cli::Release.new(work_dir)

        dev_name    = release.dev_name
        dev_version = release.dev_version

        final_name    = release.final_name
        final_version = release.final_version

        say("Dev name:      %s" % [ dev_name ? dev_name.green : "not set".red ])
        say("Dev version:   %s" % [ dev_version && dev_version > 0 ? dev_version.to_s.green : "no versions yet".red ])
        say("\n")
        say("Final name:    %s" % [ final_name ? final_name.green : "not set".red ])
        say("Final version: %s" % [ final_version && final_version > 0 ? final_version.to_s.green : "no versions yet".red ])

        header("Packages")

        package_specs = Dir[File.join(work_dir, "packages", "*", "spec")]

        if package_specs.empty?
          say("No package specs found".red)
          return
        end

        package_specs.each do |spec_file|
          if spec_file.is_a?(String) && File.file?(spec_file)
            package_dir = File.dirname(spec_file)
            spec        = YAML.load_file(spec_file) 

            package_desc = ""
            package_desc << spec["name"].green

            begin
              dev_index   = Bosh::Cli::PackagesIndex.new(File.join(package_dir, "dev_builds.yml"), File.join(package_dir, "dev_builds"))
              final_index = Bosh::Cli::PackagesIndex.new(File.join(package_dir, "final_builds.yml"), File.join(package_dir, "final_builds"))
              package_desc << "\n  last dev build:   %s" % [ dev_index.current_version ]
              package_desc << "\n  last final build: %s" % [ final_index.current_version ]
              say(package_desc)
            rescue Bosh::Cli::InvalidPackage => e
              say "Problem with package %s: %s".red % [ spec["name"], e.message ]
            end
          else
            say("Spec file #{spec_file} is invalid")
          end
        end
      end
    end

    def login(username = nil, password = nil)
      err("Please choose target first") if target.nil?

      unless options[:non_interactive]      
        username = ask("Your username: ") if username.blank?

        password_retries = 0
        while password.blank? && password_retries < 3
          password = ask("Enter password: ") { |q| q.echo = "*" }
          password_retries += 1
        end
      end

      err("Please provide username and password") if username.blank? || password.blank?
      logged_in = false

      if options[:director_checks]
        director = Bosh::Cli::Director.new(target, username, password)
        
        if director.authenticated?
          say("Logged in as '#{username}'")
          logged_in = true
        else
          say("Cannot log in as '#{username}', please try again")
          redirect(:dashboard, :login, username, nil) unless options[:non_interactive]
        end
      end

      if logged_in || !options[:director_checks]
        config.set_credentials(target, username, password)
        config.save        
      end
    end

    def logout
      err("Please choose target first") unless target
      config.set_credentials(target, nil, nil)
      config.save
      say("You are no longer logged in to '#{target}'")
    end

    def purge_cache
      if cache.cache_dir != DEFAULT_CACHE_DIR
        say("Cache directory '#{@cache.cache_dir}' differs from default, please remove manually")
      else
        FileUtils.rm_rf(cache.cache_dir)
        say("Purged cache")          
      end      
    end

    def show_target
      say(target ? "Current target is '#{target}'" : "Target not set")
    end

    def set_target(director_url)
      director = Bosh::Cli::Director.new(director_url)
      
      if options[:director_checks] && !director.exists?
        err("Cannot talk to director at '#{director_url}', please set correct target")
      end

      config.target = director_url

      if deployment
        say("WARNING! Your deployment has been unset")
        config.deployment = nil
      end
      
      config.save
      say("Target set to '#{director_url}'")
    end

  end
end

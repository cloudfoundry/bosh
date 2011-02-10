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

        say("\n")
        say "Packages"
        print_specs("package", "packages")

        say("\n")
        say "Jobs"
        print_specs("job", "jobs")
      end
    end

    def login(username = nil, password = nil)
      target_required

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
      target_required
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

    private

    def print_specs(entity, dir)

      specs = Dir[File.join(work_dir, dir, "*", "spec")]

      if specs.empty?
        say "No #{entity} specs found"
      end

      t = table [ "Name", "Dev", "Final" ]

      specs.each do |spec_file|
        if spec_file.is_a?(String) && File.file?(spec_file)
          spec = YAML.load_file(spec_file)
          name = spec["name"]

          unless name.bosh_valid_id?
            err "`#{name}' is an invalid #{entity} name, please fix before proceeding"
          end

          begin
            dev_index   = Bosh::Cli::VersionsIndex.new(File.join(work_dir, ".dev_builds", dir, name))
            final_index = Bosh::Cli::VersionsIndex.new(File.join(work_dir, ".final_builds", dir, name))

            dev_version   = dev_index.current_version
            final_version = final_index.current_version
            dev_version   = "n/a" if dev_version <= 0
            final_version = "n/a" if final_version <= 0

            t << [ name, dev_version, final_version ]
          rescue Bosh::Cli::InvalidIndex => e
            say "Problem with #{entity} index for `%s': %s".red % [ name, e.message ]
          end
        else
          say "Spec file `#{spec_file}' is invalid"
        end
      end

      say(t) unless t.rows.empty?
    end

  end
end

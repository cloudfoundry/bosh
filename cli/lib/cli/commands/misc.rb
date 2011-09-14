module Bosh::Cli::Command
  class Misc < Base

    def version
      say("Bosh %s" % [ Bosh::Cli::VERSION ])
    end

    def status

    if options[:director_checks]
        set_target(config.target, nil, false)
    end

      say("Target:     %s" % [ full_target_name + " [Director version #{config.target_version}]" || "not set" ])
      say("User:       %s" % [ logged_in? ? username : "not set" ])
      say("Deployment: %s" % [ deployment || "not set" ])

      if in_release_dir?
        header("You are in release directory")
        dev_release = Bosh::Cli::Release.dev(work_dir)
        final_release = Bosh::Cli::Release.final(work_dir)

        dev_name    = dev_release.name
        dev_version = Bosh::Cli::VersionsIndex.new(File.join(work_dir, "dev_releases")).latest_version

        final_name    = final_release.name
        final_version = Bosh::Cli::VersionsIndex.new(File.join(work_dir, "releases")).latest_version

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
          redirect(:misc, :login, username, nil) unless options[:non_interactive]
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
      say(target ? "Current target is '#{full_target_name}'" : "Target not set")
    end

    def set_target(director_url, name = nil, verbose = true)
      if name.nil?
        director_url = config.resolve_alias(:target, director_url) || director_url
      end

      if director_url.nil?
        err("Target is not set")
       return
      end

      director_url = normalize_url(director_url)
      director = Bosh::Cli::Director.new(director_url)

      if options[:director_checks]
        begin
          status = director.get_status
        rescue Bosh::Cli::AuthError
          status = { }
        rescue Bosh::Cli::DirectorError
          err("Cannot talk to director at '#{director_url}', please set correct target") if options[:director_checks]
        end
      else
        status = { "name" => "Unknown Director", "version" => "n/a" }
      end

      config.target = director_url
      config.target_name = status["name"]
      config.target_version = status["version"]
      config.set_alias(:target, name, director_url) unless name.blank?

      if deployment
        say("WARNING! Your deployment has been unset")
        config.deployment = nil
      end

      config.save

      say("Target set to '#{full_target_name}'") if verbose

      if interactive? && (config.username.blank? || config.password.blank?)
        redirect :misc, :login
      end
    end

    def dummy_job
      auth_required
      say "You are about to start the dummy job"

      nl

      status, body = director.run_dummy_job()

      responses = {
        :done          => "Done",
        :non_trackable => "Started dummy job but director at '#{target}' doesn't support dummy job tracking",
        :track_timeout => "Started dummy but timed out out while tracking status",
        :error         => "Started dummy but received an error while tracking status",
        :invalid       => "Dummy job is invalid, please fix it and run again"
      }

      say responses[status] || "Cannot run dummy job: #{body}"
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
          spec = load_yaml_file(spec_file)
          name = spec["name"]

          unless name.bosh_valid_id?
            err "`#{name}' is an invalid #{entity} name, please fix before proceeding"
          end

          begin
            dev_index   = Bosh::Cli::VersionsIndex.new(File.join(work_dir, ".dev_builds", dir, name))
            final_index = Bosh::Cli::VersionsIndex.new(File.join(work_dir, ".final_builds", dir, name))

            dev_version   = dev_index.latest_version || "n/a"
            final_version = final_index.latest_version || "n/a"

            t << [ name, dev_version.gsub(/\-dev$/, "").rjust(8), final_version.to_s.rjust(8) ]
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

# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Misc < Base
    DEFAULT_STATUS_TIMEOUT = 3 # seconds

    def version
      say("BOSH %s" % [Bosh::Cli::VERSION])
    end

    def status
      if config.target && options[:director_checks]
        say("Updating director data...", " ")

        begin
          timeout(config.status_timeout || DEFAULT_STATUS_TIMEOUT) do
            director = Bosh::Cli::Director.new(config.target)
            status = director.get_status

            config.target_name = status["name"]
            config.target_version = status["version"]
            config.target_uuid = status["uuid"]
            config.save
            say("done".green)
          end
        rescue TimeoutError
          say("timed out".red)
        rescue => e
          say("error".red)
        end
        nl
      end

      target_name = full_target_name ? full_target_name.green : "not set".red
      target_uuid = config.target_uuid ? config.target_uuid.green : "n/a".red
      user = logged_in? ? username.green : "not set".red
      deployment = config.deployment ? config.deployment.green : "not set".red

      say("Target".ljust(15) + target_name)
      say("UUID".ljust(15) + target_uuid)
      say("User".ljust(15) + user)
      say("Deployment".ljust(15) + deployment)

      if in_release_dir?
        header("You are in release directory")

        dev_name = release.dev_name
        dev_version = Bosh::Cli::VersionsIndex.new(
            File.join(work_dir, "dev_releases")).latest_version

        final_name = release.final_name
        final_version = Bosh::Cli::VersionsIndex.new(
            File.join(work_dir, "releases")).latest_version

        say("Dev name:      %s" % [dev_name ? dev_name.green : "not set".red])
        say("Dev version:   %s" % [dev_version ?
                                     dev_version.to_s.green :
                                     "no versions yet".red])
        say("\n")
        say("Final name:    %s" % [final_name ?
                                       final_name.green :
                                       "not set".red])
        say("Final version: %s" % [final_version ?
                                     final_version.to_s.green :
                                     "no versions yet".red])

        say("\n")
        say("Packages")
        print_specs("package", "packages")

        say("\n")
        say("Jobs")
        print_specs("job", "jobs")
      end
    end

    def login(username = nil, password = nil)
      target_required

      unless options[:non_interactive]
        username = ask("Your username: ").to_s if username.blank?

        password_retries = 0
        while password.blank? && password_retries < 3
          password = ask("Enter password: ") { |q| q.echo = "*" }.to_s
          password_retries += 1
        end
      end

      if username.blank? || password.blank?
        err("Please provide username and password")
      end
      logged_in = false

      if options[:director_checks]
        director = Bosh::Cli::Director.new(target, username, password)

        if director.authenticated?
          say("Logged in as '#{username}'")
          logged_in = true
        else
          say("Cannot log in as '#{username}', please try again")
          unless options[:non_interactive]
            redirect(:misc, :login, username, nil)
          end
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
      if cache.cache_dir != Bosh::Cli::DEFAULT_CACHE_DIR
        say("Cache directory '#{@cache.cache_dir}' differs from default, " +
            "please remove manually")
      else
        FileUtils.rm_rf(cache.cache_dir)
        say("Purged cache")
      end
    end

    def show_target
      say(target ?
              "Current target is '#{full_target_name.green}'" :
              "Target not set")
    end

    def set_target(director_url, name = nil)
      if name.nil?
        director_url = config.resolve_alias(:target, director_url) ||
            director_url
      end

      if director_url.blank?
        err("Target name cannot be blank")
      end

      director_url = normalize_url(director_url)
      if director_url == target
        say("Target already set to '#{full_target_name.green}'")
        return
      end

      director = Bosh::Cli::Director.new(director_url)

      if options[:director_checks]
        begin
          status = director.get_status
        rescue Bosh::Cli::AuthError
          status = {}
        rescue Bosh::Cli::DirectorError
          err("Cannot talk to director at '#{director_url}', " +
              "please set correct target")
        end
      else
        status = { "name" => "Unknown Director", "version" => "n/a" }
      end

      config.target = director_url
      config.target_name = status["name"]
      config.target_version = status["version"]
      config.target_uuid = status["uuid"]

      unless name.blank?
        config.set_alias(:target, name, director_url)
      end

      unless status["uuid"].blank?
        config.set_alias(:target, status["uuid"], director_url)
      end

      config.save
      say("Target set to '#{full_target_name.green}'")

      if interactive? && (config.username.blank? || config.password.blank?)
        redirect(:misc, :login)
      end
    end

    def list_targets
      # TODO: Bonus point will be checking each director status
      # (maybe an --status option?)
      targets = config.aliases(:target) || {}

      err("No targets found") if targets.size == 0

      targets_table = table do |t|
        t.headings = [ "Name", "Director URL" ]
        targets.each { |row| t << [row[0], row[1]] }
      end

      say("\n")
      say(targets_table)
      say("\n")
      say("Targets total: %d" % targets.size)
    end

    def set_alias(name, value)
      config.set_alias(:cli, name, value.to_s.strip)
      config.save
      say("Alias `#{name.green}' created for command `#{value.green}'")
    end

    def list_aliases
      aliases = config.aliases(:cli) || {}

      err("No aliases found") if aliases.size == 0

      sorted = aliases.sort_by { |name, value| name }
      aliases_table = table do |t|
        t.headings = [ "Alias", "Command" ]
        sorted.each { |row| t << [row[0], row[1]] }
      end

      say("\n")
      say(aliases_table)
      say("\n")
      say("Aliases total: %d" % aliases.size)
    end

    private

    def print_specs(entity, dir)
      specs = Dir[File.join(work_dir, dir, "*", "spec")]

      if specs.empty?
        say("No #{entity} specs found")
      end

      t = table ["Name", "Dev", "Final"]

      specs.each do |spec_file|
        if spec_file.is_a?(String) && File.file?(spec_file)
          spec = load_yaml_file(spec_file)
          name = spec["name"]

          unless name.bosh_valid_id?
            err("`#{name}' is an invalid #{entity} name, " +
                "please fix before proceeding")
          end

          begin
            dev_index   = Bosh::Cli::VersionsIndex.new(
                File.join(work_dir, ".dev_builds", dir, name))
            final_index = Bosh::Cli::VersionsIndex.new(
                File.join(work_dir, ".final_builds", dir, name))

            dev_version   = dev_index.latest_version || "n/a"
            final_version = final_index.latest_version || "n/a"

            t << [name, dev_version.gsub(/\-dev$/, "").rjust(8),
                  final_version.to_s.rjust(8)]
          rescue Bosh::Cli::InvalidIndex => e
            say("Problem with #{entity} index for `#{name}': #{e.message}".red)
          end
        else
          say("Spec file `#{spec_file}' is invalid")
        end
      end

      say(t) unless t.rows.empty?
    end

  end
end

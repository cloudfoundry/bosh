# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class Misc < Base
    DEFAULT_STATUS_TIMEOUT = 3 # seconds

    # bosh version
    usage "version"
    desc  "Show version"
    def version
      say("BOSH %s" % [Bosh::Cli::VERSION])
    end

    # bosh status
    usage "status"
    desc  "Show current status (current target, user, deployment info etc)"
    option "--uuid", "Only print director UUID"
    def status
      if options[:uuid]
        begin
          say(get_director_status["uuid"])
        rescue => e
          err("Error fetching director status: #{e.message}")
        end
      else
        say("Config".make_green)
        print_value("", config.filename)

        nl
        say("Director".make_green)
        if target.nil?
          say("  not set".make_yellow)
        else
          begin
            status = get_director_status

            print_value("Name", status["name"])
            print_value("URL", target_url)
            print_value("Version", status["version"])
            print_value("User", username, "not logged in")
            print_value("UUID", status["uuid"])
            print_value("CPI", status["cpi"], "n/a")
            print_feature_list(status["features"]) if status["features"]

            unless options[:target]
              config.target_name = status["name"]
              config.target_version = status["version"]
              config.target_uuid = status["uuid"]
              config.save
            end
          rescue TimeoutError
            say("  timed out fetching director status".make_red)
          rescue => e
            say("  error fetching director status: #{e.message}".make_red)
          end
        end

        nl
        say("Deployment".make_green)

        if deployment
          print_value("Manifest", deployment)
        else
          say("  not set".make_yellow)
        end

        if in_release_dir?
          nl
          say("Release".make_green)

          dev_version = Bosh::Cli::VersionsIndex.new(
            File.join(work_dir, "dev_releases")).latest_version

          final_version = Bosh::Cli::VersionsIndex.new(
            File.join(work_dir, "releases")).latest_version

          dev = release.dev_name
          dev += "/#{dev_version}" if dev && dev_version

          final = release.final_name
          final += "/#{final_version}" if final && final_version

          print_value("dev", dev)
          print_value("final", final)
        end
      end
    end

    # bosh login
    usage "login"
    desc  "Log in to currently targeted director. " +
          "The username and password can also be " +
          "set in the BOSH_USER and BOSH_PASSWORD " +
          "environment variables."
    def login(username = nil, password = nil)
      target_required

      if interactive?
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

      #Converts HighLine::String to String
      username = username.to_s
      password = password.to_s

      director.user = username
      director.password = password

      if director.authenticated?
        say("Logged in as `#{username}'".make_green)
        logged_in = true
      elsif non_interactive?
        err("Cannot log in as `#{username}'".make_red)
      else
        say("Cannot log in as `#{username}', please try again".make_red)
        login(username)
      end

      if logged_in
        config.set_credentials(target, username, password)
        config.save
      end
    end

    # bosh logout
    usage "logout"
    desc  "Forget saved credentials for targeted director"
    def logout
      target_required
      config.set_credentials(target, nil, nil)
      config.save
      say("You are no longer logged in to `#{target}'".make_yellow)
    end

    # bosh target
    usage "target"
    desc  "Choose director to talk to (optionally creating an alias). " +
          "If no arguments given, show currently targeted director"
    def set_target(director_url = nil, name = nil)
      if director_url.nil?
        show_target
        return
      end

      if name.nil?
        director_url =
          config.resolve_alias(:target, director_url) || director_url
      end

      if director_url.blank?
        err("Target name cannot be blank")
      end

      director_url = normalize_url(director_url)
      if target && director_url == normalize_url(target)
        say("Target already set to `#{target_name.make_green}'")
        return
      end

      director = Bosh::Cli::Client::Director.new(director_url)

      begin
        status = director.get_status
      rescue Bosh::Cli::AuthError
        status = {}
      rescue Bosh::Cli::DirectorError
        err("Cannot talk to director at `#{director_url}', " +
            "please set correct target")
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
      say("Target set to `#{target_name.make_green}'")

      if interactive? && !logged_in?
        redirect("login")
      end
    end

    # bosh targets
    usage "targets"
    desc  "Show the list of available targets"
    def list_targets
      targets = config.aliases(:target) || {}

      err("No targets found") if targets.empty?

      targets_table = table do |t|
        t.headings = [ "Name", "Director URL" ]
        targets.each { |row| t << [row[0], row[1]] }
      end

      nl
      say(targets_table)
      nl
      say("Targets total: %d" % targets.size)
    end

    # bosh alias
    usage "alias"
    desc  "Create an alias <name> for command <command>"
    def set_alias(name, command)
      config.set_alias(:cli, name, command.to_s.strip)
      config.save
      say("Alias `#{name.make_green}' created for command `#{command.make_green}'")
    end

    # bosh aliases
    usage "aliases"
    desc  "Show the list of available command aliases"
    def list_aliases
      aliases = config.aliases(:cli) || {}
      err("No aliases found") if aliases.empty?

      sorted = aliases.sort_by { |name, _| name }
      aliases_table = table do |t|
        t.headings = %w(Alias Command)
        sorted.each { |row| t << [row[0], row[1]] }
      end

      nl
      say(aliases_table)
      nl
      say("Aliases total: %d" % aliases.size)
    end

    private

    def print_value(label, value, if_none = nil)
      if value
        message = label.ljust(10) + ' ' + value.make_yellow
      else
        message = label.ljust(10) + ' ' + (if_none || "n/a").make_yellow
      end
      say(message.indent(2))
    end

    def show_target
      if config.target
        if interactive?
          if config.target_name
            name = "#{config.target} (#{config.target_name})"
          else
            name = config.target
          end
          say("Current target is #{name.make_green}")
        else
          say(config.target)
        end
      else
        err("Target not set")
      end
    end

    def print_specs(entity, dir)
      specs = Dir[File.join(work_dir, dir, "*", "spec")]

      if specs.empty?
        say("No #{entity} specs found")
      end

      t = table %w(Name Dev Final)

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
            say("Problem with #{entity} index for `#{name}': #{e.message}".make_red)
          end
        else
          say("Spec file `#{spec_file}' is invalid")
        end
      end

      say(t) unless t.rows.empty?
    end

    def print_feature_list(features)
      if features.respond_to?(:each)
        features.each do |feature, info|
          # Old director only returns status as a Boolean
          if info.kind_of?(Hash)
            status = info["status"]
            extras = info["extras"]
          else
            status = info
            extras = nil
          end
          print_value(feature, format_feature_status(status, extras))
        end
      else
        say("Unknown feature list: #{features.inspect}".make_red)
      end
    end

    def format_feature_status(status, extras)
      if status.nil?
        "n/a"
      elsif status
        "enabled #{format_feature_extras(extras)}"
      else
        "disabled"
      end
    end

    def format_feature_extras(extras)
      return "" if extras.nil? || extras.empty?

      result = []
      extras.each do |name, value|
        result << "#{name}: #{value}"
      end

      "(#{result.join(", ")})"
    end

    def get_director_status
      timeout(config.status_timeout || DEFAULT_STATUS_TIMEOUT) do
        Bosh::Cli::Client::Director.new(target).get_status
      end
    end
  end
end

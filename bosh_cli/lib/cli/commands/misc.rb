module Bosh::Cli::Command
  class Misc < Base
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
            print_value("User", status["user"], "not logged in")
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
      end
    end

    # bosh target
    usage "target"
    desc  "Choose director to talk to (optionally creating an alias). " +
          "If no arguments given, show currently targeted director"
    option '--ca-cert FILE', String, 'Path to client certificate provided to UAA server'
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

      old_ca_cert_path = config.ca_cert
      expanded_ca_cert_path = config.save_ca_cert_path(options[:ca_cert])
      if old_ca_cert_path != expanded_ca_cert_path
        say("Updating certificate file path to `#{expanded_ca_cert_path.to_s.make_green}'")
        nl
      end

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
      Bosh::Cli::Client::Director.new(target, credentials).get_status
    end
  end
end

# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class PropertyManagement < Base
    include Bosh::Cli::DeploymentHelper

    def set(name, value)
      prepare
      show_header

      begin
        status, body = director.get_property(@deployment_name, name)
        existing_property = status == 200
      rescue Bosh::Cli::DirectorError
        existing_property = false
      end

      if existing_property
        say("Current `#{name.green}' value is " +
            "`#{format_property(body["value"]).green}'")
      else
        say("This will be a new property")
      end

      prompt = "Are you sure you want to set property" +
          " `#{name.green}' to `#{format_property(value).green}'? " +
          "(type yes to proceed): "

      if interactive? && ask(prompt) != "yes"
        err("Canceled")
      end

      if existing_property
        status, body = director.update_property(@deployment_name, name, value)
      else
        status, body = director.create_property(@deployment_name, name, value)
      end

      if status == 204
        say("Property `#{name.green}' set to `#{value.green}'")
      else
        err(director.parse_error_message(status, body))
      end
    end

    def unset(name)
      prepare
      show_header

      prompt = "Are you sure you want to unset property " +
          "`#{name.green}'? (type yes to proceed): "

      if interactive? && ask(prompt) != "yes"
        err("Canceled")
      end

      status, body = director.delete_property(@deployment_name, name)

      if status == 204
        say("Property `#{name.green}' has been unset")
      else
        err(director.parse_error_message(status, body))
      end
    end

    def get(name)
      prepare
      show_header

      status, body = director.get_property(@deployment_name, name)
      if status == 200
        say("Property `#{name.green}' value is " +
            "`#{format_property(body["value"]).green}'")
      else
        err(director.parse_error_message(status, body))
      end
    end

    def list(*args)
      prepare
      terse = args.include?("--terse")
      show_header unless terse

      properties = director.list_properties(@deployment_name)
      unless properties.kind_of?(Enumerable)
        err("Invalid properties format, please check your director")
      end

      output = properties.sort do |p1, p2|
        p1["name"] <=> p2["name"]
      end.map do |property|
        [property["name"], format_property(property["value"])]
      end

      if terse
        output.each { |row| say("#{row[0]}\t#{row[1]}") }
      else
        if output.size > 0
          properties_table = table do |t|
            t.headings = ["Name", "Value"]
            output.each { |row| t << [row[0], row[1].truncate(40)] }
          end
          say(properties_table)
        else
          say("No properties found")
        end
      end
    end

    private

    def prepare
      auth_required
      manifest = prepare_deployment_manifest
      @deployment_name = manifest["name"]
    end

    def show_header
      say("Target #{target_name.green}")
      say("Deployment #{@deployment_name.green}")
      nl
    end

    def format_property(value)
      value.gsub("\n", "\\n")
    end

  end
end

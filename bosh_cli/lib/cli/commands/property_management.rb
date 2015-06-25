# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli::Command
  class PropertyManagement < Base
    # bosh set property
    usage "set property"
    desc "Set deployment property"
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
        say("Current `#{name.make_green}' value is " +
            "`#{format_property(body["value"]).make_green}'")
      else
        say("This will be a new property")
      end

      prompt = "Are you sure you want to set property" +
        " `#{name.make_green}' to `#{format_property(value).make_green}'?"

      unless confirmed?(prompt)
        err("Canceled")
      end

      if existing_property
        status, body = director.update_property(@deployment_name, name, value)
      else
        status, body = director.create_property(@deployment_name, name, value)
      end

      if status == 204
        say("Property `#{name.make_green}' set to `#{value.make_green}'")
      else
        err(director.parse_error_message(status, body))
      end
    end

    # bosh unset property
    usage "unset property"
    desc "Unset deployment property"
    def unset(name)
      prepare
      show_header

      prompt = "Are you sure you want to unset property " +
        "`#{name.make_green}'?"

      unless confirmed?(prompt)
        err("Canceled")
      end

      status, body = director.delete_property(@deployment_name, name)

      if status == 204
        say("Property `#{name.make_green}' has been unset")
      else
        err(director.parse_error_message(status, body))
      end
    end

    # bosh get property
    usage "get property"
    desc "Get deployment property"
    def get(name)
      prepare
      show_header

      status, body = director.get_property(@deployment_name, name)
      if status == 200
        say("Property `#{name.make_green}' value is " +
            "`#{format_property(body["value"]).make_green}'")
      else
        err(director.parse_error_message(status, body))
      end
    end

    # bosh properties
    usage "properties"
    desc "List deployment properties"
    option "--terse", "easy to parse output"
    def list
      prepare
      terse = options[:terse]
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
            t.headings = %w(Name Value)
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
      @deployment_name = prepare_deployment_manifest(show_state: true).name
    end

    def show_header
      say("Target #{target_name.make_green}")
      say("Deployment #{@deployment_name.make_green}")
      nl
    end

    def format_property(value)
      value.gsub("\n", "\\n")
    end

  end
end

module Bosh::Cli::Command
  class PropertyManagement < Base
    include Bosh::Cli::DeploymentHelper

    ["deployment", "release"].each do |scope_type|
      ["set", "unset", "get", "list"].each do |op|
        define_method("#{scope_type}_#{op}") do |*args|
          send(op.to_sym, scope_type, *args)
        end
      end
    end

    private

    def set(scope_type, scope_name, name, value)
      auth_required
      show_header

      status, body = director.get_property(scope_type, scope_name, name)
      existing_property = status == 200

      if existing_property
        say "Current `#{name.green}' value is `#{format_property(body["value"]).green}'"
      else
        say "This will be a new property"
      end
      nl

      prompt = "Are you sure you want to set property `#{name.green}' to `#{format_property(value).green}'? (type yes to proceed): "
      err "Canceled" if interactive? && ask(prompt) != "yes"

      if existing_property
        status, body = director.update_property(scope_type, scope_name, name, value)
      else
        status, body = director.create_property(scope_type, scope_name, name, value)
      end

      nl
      if status == 204
        say "Property `#{name.green}' set to `#{value.green}'"
      else
        err director.parse_error_message(status, body)
      end
    end

    def unset(scope_type, scope_name, name)
      auth_required
      show_header
      nl

      prompt = "Are you sure you want to unset property `#{name.green}'? (type yes to proceed): "
      err "Canceled" if interactive? && ask(prompt) != "yes"

      status, body = director.delete_property(scope_type, scope_name, name)

      nl
      if status == 204
        say "Property `#{name.green}' has been unset"
      else
        err director.parse_error_message(status, body)
      end
    end

    def get(scope_type, scope_name, name)
      auth_required
      show_header
      nl

      status, body = director.get_property(scope_type, scope_name, name)
      if status == 200
        say "Property `#{name.green}' value is `#{format_property(body["value"]).green}'"
      else
        err director.parse_error_message(status, body)
      end
    end

    def list(*args)
      auth_required
      scope_type, scope_name = args.shift(2)

      terse = args.include?("--terse")
      unless terse
        show_header
        nl
      end

      properties = director.list_properties(scope_type, scope_name)
      unless properties.kind_of?(Enumerable)
        err "Invalid properties format, please check your director"
      end

      output = properties.sort { |a,b| a["name"] <=> b["name"] }.map do |property|
        [ property["name"], format_property(property["value"]) ]
      end

      if terse
        output.each { |row| say "#{row[0]}\t#{row[1]}" }
      else
        if output.size > 0
          properties_table = table do |t|
            t.headings = [ "Name", "Value" ]
            output.each { |row| t << [ row[0], row[1].truncate(40) ] }
          end
          say properties_table
        else
          say "No properties found"
        end
      end
    end

    private

    def show_header
      say "Target #{target_name.green}"
    end

    def format_property(value)
      value.gsub("\n", "\\n")
    end

  end
end

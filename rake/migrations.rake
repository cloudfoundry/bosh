# Copyright (c) 2009-2012 VMware, Inc.

require "bosh_cli_plugin_aws/migration_helper"

namespace "migrations" do

  desc "Generate new migration"
  task "new", :component, :name, :type do |task, args|
    type = args[:type]
    component = args[:component]
    if type.nil? && component == 'director'
      puts "Please provide migration type: rake #{task.name}[<component>,<name>,<type>]"
      exit(1)
    elsif type && !File.directory?(Bosh::Aws::MigrationHelper.migration_directory(args))
      Dir.chdir("#{component}/db/migrations")
      valid_types = Dir["*"].select { |file| File.directory?(file) }
      if valid_types.empty?
        puts "Can't find any types in #{component}/db/migrations please check you have the correct component"
      else
        puts "Invalid type: '#{type}', must be one of: #{valid_types.join(", ")}"
      end
      exit(1)
    end

    name = args[:name]
    if name.nil?
      puts "Please provide migration name: rake #{task.name}[<component>,<name>,<type>]"
      exit(1)
    end

    timestamp = Time.new.getutc.strftime("%Y%m%d%H%M%S")
    filename = "#{migration_directory(args)}/#{timestamp}_#{name}.rb"

    puts "Creating #{filename}"
    FileUtils.touch(filename)
  end

  namespace "aws" do
    desc "Generate a new AWS migration"
    task "new", :name do |task, args|
      name = args[:name]

      if name.nil?
        puts "Please provide migration name: rake #{task.name}[<name>]"
        exit(1)
      end

      Bosh::Aws::MigrationHelper.generate_migration_file(name)
    end
  end
end
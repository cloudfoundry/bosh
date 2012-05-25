# Copyright (c) 2009-2012 VMware, Inc.

namespace "migration" do
  desc "Generate new migration"
  task "new", :type, :name do |task, args|
    type = args[:type]
    if type.nil?
      puts "Please provide migration type: rake #{task.name}[<type>, <name>]"
      exit(1)
    elsif !File.directory?("db/migrations/#{type}")
      Dir.chdir("db/migrations")
      valid_types = Dir["*"].select {|file| File.directory?(file)}
      puts "Invalid type: '#{type}', must be one of: #{valid_types.join(", ")}"
      exit(1)
    end

    name = args[:name]
    if name.nil?
      puts "Please provide migration name: rake #{task.name}[<type>, <name>]"
      exit(1)
    end

    timestamp = Time.new.getutc.strftime("%Y%m%d%H%M%S")
    filename = "db/migrations/#{type}/#{timestamp}_#{name}.rb"

    puts "Creating #{filename}"
    FileUtils.touch(filename)
  end

  desc "Run migrations"
  task "run", :config do |task, args|
    config_file = args[:config]
    if config_file.nil?
      abort("Please provide a path to the config file: " +
                "rake #{task.name}[<path to config file>]")
    elsif !File.file?(config_file)
      abort("Invalid config file '#{config_file}'")
    end

    config = YAML.load_file(config_file)
    unless config["db"] && config["db"]["database"]
      abort ("Director database config missing from config file")
    end

    migrate(config["db"]["database"], nil, "db/migrations/director")
    migrate(config["db"]["database"], "vsphere_cpi_schema",
            "db/migrations/vsphere_cpi")

    if config["dns"] && config["dns"]["db"]
      migrate(config["dns"]["db"]["database"], "dns_schema",
              "db/migrations/dns")
    end
  end

  task "manual", :type, :db, :schema do |task, args|
    migrate(args[:db], args[:schema], "db/migrations/#{args[:type]}")
  end

  def migrate(database, schema_table, dir, target = nil)
    dir = "\"#{dir}\""
    schema_table = schema_table ? "\"#{schema_table}\"" : "nil"
    target = target ? "\"#{target}\"" : "nil"

    script=<<-EOS
      Sequel.extension :migration
      Sequel::TimestampMigrator.new(DB, #{dir}, :table => #{schema_table},
        :target => #{target}).run
    EOS

    IO.popen("bundle exec sequel -E '#{database}'", :mode => "r+") do |io|
      io.write(script)
      io.close_write
      puts io.read
    end

    exit(1) unless $?.exitstatus == 0
  end
end
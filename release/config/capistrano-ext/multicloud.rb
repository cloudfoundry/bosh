require 'fileutils'

unless Capistrano::Configuration.respond_to?(:instance)
  abort "multicloud requires Capistrano 2"
end

Capistrano::Configuration.instance.load do
  location = fetch(:cloud_dir, "clouds")

  unless exists?(:clouds)
    set :clouds, Dir["#{location}/*"].select { |f| File.directory?(f) }.map{ |f| File.basename(f) }
  end

  clouds.each do |name|
    desc "Set the target cloud to `#{name}'."
    task(name) do
      set :cloud, name.to_sym
      load "#{location}/#{cloud}/cloud.rb"
    end
  end

  on :load do
    if clouds.include?(ARGV.first)
      # Execute the specified cloud so that recipes required in cloud can contribute to task list
      find_and_execute_task(ARGV.first) if ARGV.any?{ |option| option =~ /-T|--tasks|-e|--explain/ }
    end
  end

  namespace :multicloud do
    desc "[internal] Ensure that a cloud has been selected."
    task :ensure do
      if !exists?(:cloud)
        abort "No cloud specified. Please specify one of: #{clouds.join(', ')} (e.g. `cap #{clouds.first} #{ARGV.last}')"
      end
    end

    desc "Stub out the cloud config files."
    task :prepare do
      FileUtils.mkdir_p(location)
      clouds.each do |name|
        file = File.join(location, name + ".rb")
        unless File.exists?(file)
          File.open(file, "w") do |f|
            f.puts "# #{name.upcase}-specific deployment configuration"
            f.puts "# please put general deployment config in config/deploy.rb"
          end
        end
      end
    end
  end

  on :start, "multicloud:ensure", :except => clouds + ['multicloud:prepare']
end
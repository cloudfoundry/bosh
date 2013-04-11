module Bosh
  module Aws
    module MigrationHelper
      def self.migration_directory(args)
        "#{args[:component]}/db/migrations/#{args[:type]}"
      end

      def self.aws_migration_directory
        File.expand_path("../../migrations", File.dirname(__FILE__))
      end

      def self.timestamp
        Time.new.getutc.strftime("%Y%m%d%H%M%S")
      end

      def self.generate_migration_file(name)
        filename = "#{aws_migration_directory}/#{timestamp}_#{name}.rb"
        puts "Creating #{filename}"
        File.open(filename, 'w+') { |f| f.write(merge_migration_template(name)) }
      end

      def self.merge_migration_template(name)
        #Used by template
        klass_name = to_class_name(name)

        template_file_path = File.expand_path("../../templates/aws_migration.erb", File.dirname(__FILE__))
        template = ERB.new(File.new(template_file_path).read())
        template.result(binding)
      end

      def self.to_class_name(name)
        name.split('_').map(&:capitalize).join('')
      end
    end
  end
end

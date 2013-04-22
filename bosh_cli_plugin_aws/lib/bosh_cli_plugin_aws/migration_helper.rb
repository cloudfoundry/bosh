module Bosh
  module Aws
    module MigrationHelper
      class Template
        attr_reader :timestamp_string, :name, :class_name

        def initialize(name)
          @timestamp_string = Time.new.getutc.strftime("%Y%m%d%H%M%S")
          @name = name
          @class_name = MigrationHelper.to_class_name(name)
        end

        def file_prefix
          "#{timestamp_string}_#{name}"
        end

        def render(template_name = "aws_migration")
          template_file_path = File.expand_path("../../templates/#{template_name}.erb", File.dirname(__FILE__))
          template = ERB.new(File.new(template_file_path).read(), 0, '<>%-')
          template.result(binding)
        end
      end

      def self.migration_directory(args)
        "#{args[:component]}/db/migrations/#{args[:type]}"
      end

      def self.aws_migration_directory
        File.expand_path("../../migrations", File.dirname(__FILE__))
      end

      def self.aws_spec_migration_directory
        File.expand_path("../../spec/migrations", File.dirname(__FILE__))
      end

      def self.generate_migration_file(name)
        template = Template.new(name)

        filename = "#{aws_migration_directory}/#{template.file_prefix}.rb"
        spec_filename = "#{aws_spec_migration_directory}/#{template.file_prefix}_spec.rb"

        puts "Creating #{filename} and #{spec_filename}"

        File.open(filename, 'w+') { |f| f.write(template.render) }
        File.open(spec_filename, 'w+') { |f| f.write(template.render("aws_migration_spec")) }
      end

      def self.to_class_name(name)
        name.split('_').map(&:capitalize).join('')
      end
    end
  end
end

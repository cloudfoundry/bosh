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

      class RdsDb

        attr_accessor :instance_id, :receipt, :tag, :subnets, :subnet_ids

        def initialize(args = {})
          RdsDb.aws_rds  = args.fetch(:aws_rds)
          @instance_id   = args.fetch(:instance_id)
          @tag           = args.fetch(:tag)
          @subnets       = args.fetch(:subnets)
          @subnet_ids    = args.fetch(:subnet_ids)
          @vpc_receipt   = args.fetch(:vpc_receipt)
          @rds_db_conf   = args.fetch(:rds_db_conf)
        end

        def create!
          return if RdsDb.aws_rds.database_exists? @instance_id
          creation_opts = [@instance_id, @subnet_ids, @vpc_receipt["vpc"]["id"]]

          if @rds_db_conf["aws_creation_options"]
            creation_opts << @rds_db_conf["aws_creation_options"]
          end

          @response = RdsDb.aws_rds.create_database(*creation_opts)
          output_rds_properties
        end

        def output_rds_properties
          RdsDb.receipt["deployment_manifest"] ||= {}
          RdsDb.receipt["deployment_manifest"]["properties"] ||= {}
          RdsDb.receipt["deployment_manifest"]["properties"][@instance_id] = {
              "db_scheme" => @response[:engine],
              "roles" => [
                  {
                      "tag" => "admin",
                      "name" => @response[:master_username],
                      "password" => @response[:master_user_password]
                  }
              ],
              "databases" => [
                  {
                      "tag" => @tag,
                      "name" => @instance_id
                  }
              ]
          }
        end

        def self.aws_rds
          @aws_rds
        end

        def self.aws_rds=(arg)
          @aws_rds = arg
        end

        def self.receipt
          @receipt ||= {}
        end

        def self.was_rds_eventually_available?
          return true if all_rds_instances_available?(:silent => true)
          (1..180).any? do |attempt|
            Kernel.sleep 10
            all_rds_instances_available?
          end
        end

        def self.all_rds_instances_available?(opts = {})
          silent = opts[:silent]
          say("checking rds status...") unless silent
          aws_rds.databases.all? do |db_instance|
            say("  #{db_instance.db_name} #{db_instance.db_instance_status} #{db_instance.endpoint_address}") unless silent
            !db_instance.endpoint_address.nil?
          end
        end
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

      def self.all_rds_instances_available?(rds, opts = {})
        silent = opts[:silent]
        say("checking rds status...") unless silent
        rds.databases.all? do |db_instance|
          say("  #{db_instance.db_name} #{db_instance.db_instance_status} #{db_instance.endpoint_address}") unless silent
          !db_instance.endpoint_address.nil?
        end
      end
    end
  end
end

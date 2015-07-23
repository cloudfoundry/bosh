require "securerandom"

module Bosh
  module AwsCliPlugin
    class RDS
      DEFAULT_RDS_OPTIONS = {
          :allocated_storage => 5,
          :db_instance_class => "db.m1.small",
          :engine => "mysql",
          :multi_az => true,
          :engine_version => "5.5.40a"
      }
      DEFAULT_RDS_PROTOCOL = :tcp
      DEFAULT_MYSQL_PORT = 3306

      def initialize(credentials)
        @credentials = credentials
        @aws_provider = AwsProvider.new(@credentials)
      end

      def create_database(name, subnet_ids, vpc_id, options = {})
        create_db_parameter_group('utf8')
        vpc = Bosh::AwsCliPlugin::VPC.find(Bosh::AwsCliPlugin::EC2.new(@credentials), vpc_id)
        create_vpc_db_security_group(vpc, name) if vpc.security_group_by_name(name).nil?
        create_subnet_group(name, subnet_ids) unless subnet_group_exists?(name)

        # symbolize options keys
        options = options.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }

        creation_options = DEFAULT_RDS_OPTIONS.merge(options)
        creation_options[:db_instance_identifier] = name
        creation_options[:db_name]              ||= name
        creation_options[:vpc_security_group_ids] = [vpc.security_group_by_name(name).id]
        creation_options[:db_subnet_group_name]   = name
        creation_options[:db_parameter_group_name]     = 'utf8'
        creation_options[:master_username]      ||= generate_user
        creation_options[:master_user_password] ||= generate_password
        response = aws_rds_client.create_db_instance(creation_options)
        response.data.merge(:master_user_password => creation_options[:master_user_password])
      end

      def databases
        aws_rds.db_instances
      end

      def database(name)
        databases.find { |v| v.id == name }
      end

      def database_exists?(name)
        !database(name).nil?
      end

      def delete_databases
        databases.each { |db| db.delete(skip_final_snapshot: true) unless db.db_instance_status == "deleting" }
      end

      def database_names
        databases.inject({}) do |memo, db_instance|
          memo[db_instance.id] = db_instance.name
          memo
        end
      end

      def subnet_group_exists?(name)
        aws_rds_client.describe_db_subnet_groups(:db_subnet_group_name => name)
        return true
      rescue AWS::RDS::Errors::DBSubnetGroupNotFoundFault
        return false
      end

      def db_parameter_group_names
        charset = 'utf8'
        param_names = %w(character_set_server
                         character_set_client
                         character_set_results
                         character_set_database
                         character_set_connection)

        params = param_names.map{|param_name| {:parameter_name => param_name,
                                      :parameter_value => charset,
                                      :apply_method => 'immediate'}}

        params << {:parameter_name => 'collation_connection',
                                               :parameter_value => 'utf8_unicode_ci',
                                               :apply_method => 'immediate'}
        params << {:parameter_name => 'collation_server',
                                           :parameter_value => 'utf8_unicode_ci',
                                           :apply_method => 'immediate'}
        params
      end

      def create_db_parameter_group(name)
        aws_rds_client.describe_db_parameter_groups(:db_parameter_group_name => name)
      rescue AWS::RDS::Errors::DBParameterGroupNotFound
        aws_rds_client.create_db_parameter_group(:db_parameter_group_name => name,
        :db_parameter_group_family => 'mysql5.5', :description => name)
        aws_rds_client.modify_db_parameter_group(:db_parameter_group_name => name,
            :parameters => db_parameter_group_names)
      end

      def delete_db_parameter_group(name)
        aws_rds_client.describe_db_parameter_groups(:db_parameter_group_name => name)
        aws_rds_client.delete_db_parameter_group(:db_parameter_group_name => name)
      rescue AWS::RDS::Errors::DBParameterGroupNotFound
      end

      def create_subnet_group(name, subnet_ids)
        aws_rds_client.create_db_subnet_group(
            :db_subnet_group_name => name,
            :db_subnet_group_description => name,
            :subnet_ids => subnet_ids
        )
      end

      def subnet_group_names
        aws_rds_client.describe_db_subnet_groups.data[:db_subnet_groups].map { |sg| sg[:db_subnet_group_name] }
      end

      def delete_subnet_group(name)
        aws_rds_client.delete_db_subnet_group(:db_subnet_group_name => name)
      end

      def delete_subnet_groups
        subnet_group_names.each { |name| delete_subnet_group(name) }
      end

      def create_vpc_db_security_group(vpc, name)
        group_spec = {
            "name" => name,
            "ingress" => [
                {
                    "ports" => DEFAULT_MYSQL_PORT,
                    "protocol" => DEFAULT_RDS_PROTOCOL,
                    "sources" => vpc.cidr_block,
                },
            ],
        }

        vpc.create_security_groups([group_spec])
      end

      def security_group_names
        aws_rds_client.describe_db_security_groups.data[:db_security_groups].map { |sg| sg[:db_security_group_name] }
      end

      def delete_security_group(name)
        aws_rds_client.delete_db_security_group(:db_security_group_name => name)
      end

      def delete_security_groups
        security_group_names.each do |name|
          delete_security_group(name) unless name == "default"
        end
      end

      def aws_rds
        aws_provider.rds
      end

      def aws_rds_client
        aws_provider.rds_client
      end

      private

      attr_reader :aws_provider

      def generate_user
        generate_credential("u", 7)
      end

      def generate_password
        generate_credential("p", 16)
      end

      def generate_credential(prefix, length)
        "#{prefix}#{SecureRandom.hex(length)}"
      end
    end
  end
end

module Bosh::AwsCliPlugin
  class RdsDestroyer
    def initialize(ui, config)
      @ui = ui
      @credentials = config['aws']
    end

    def delete_all
      formatted_names = rds.database_names.map { |instance, db| "#{instance}\t(database_name: #{db})" }

      @ui.say("THIS IS A VERY DESTRUCTIVE OPERATION AND IT CANNOT BE UNDONE!\n".make_red)
      @ui.say("Database Instances:\n\t#{formatted_names.join("\n\t")}")

      if @ui.confirmed?('Are you sure you want to delete all databases?')
        rds.delete_databases unless formatted_names.empty?

        unless all_rds_instances_deleted?
          raise 'not all rds instances could be deleted'
        end

        rds.delete_subnet_groups
        rds.delete_security_groups
        rds.delete_db_parameter_group('utf8')
      end
    end

    private

    def all_rds_instances_deleted?
      120.times do
        return true if rds.databases.count == 0

        @ui.say('waiting for RDS deletion...')
        sleep(10)

        rds.databases.each do |db_instance|
          begin
            @ui.say("  #{db_instance.db_name} #{db_instance.db_instance_status}")
          rescue ::AWS::RDS::Errors::DBInstanceNotFound
            # It is possible for a db to be deleted between the time the
            # each returns an instance and when we print out its info
          end
        end
      end

      false
    end

    def rds
      @rds ||= Bosh::AwsCliPlugin::RDS.new(@credentials)
    end
  end
end

module Bosh
  module Aws
    class RDS

      def initialize(credentials)
        @credentials = credentials
      end

      def delete_databases
        aws_rds.db_instances.each {|db| db.delete(skip_final_snapshot: true) }
      end

      def database_names
        aws_rds.db_instances.inject({}) do |memo, db_instance|
          memo[db_instance.id] = db_instance.name
          memo
        end
      end

      def aws_rds
        @aws_eds ||= ::AWS::RDS.new(@credentials)
      end
    end
  end
end
class CreateRdsDbs < Bosh::Aws::Migration
  include Bosh::Aws::MigrationHelper

  def execute
    if !config["rds"]
      say "rds not set in config.  Skipping"
      return
    end

    vpc_receipt = load_receipt("aws_vpc_receipt")
    vpc_subnets = vpc_receipt["vpc"]["subnets"]

    begin
      db_names   = %w(ccdb uaadb mysql-service-public mysql-service-cf-internal)
      db_configs = config['rds'].select {|c| db_names.include?(c['instance']) }

      db_configs.each do |rds_db_conf|
        rds_args = {
            :instance_id => rds_db_conf["instance"],
            :tag         => rds_db_conf["tag"],
            :subnets     => subnets = rds_db_conf["subnets"],
            :subnet_ids  => subnets.map {|s| vpc_subnets[s]},
            :vpc_receipt => vpc_receipt,
            :rds_db_conf => rds_db_conf,
            :aws_rds     => rds
        }

        RdsDb.new(rds_args).create!
      end

      if RdsDb.was_rds_eventually_available?

        db_configs.each do |rds_db_config|
          instance_id = rds_db_config["instance"]

          if deployment_properties(RdsDb.receipt)[instance_id]
            db_instance = RdsDb.aws_rds.database(instance_id)
            RdsDb.receipt["deployment_manifest"]["properties"][instance_id].merge!(
                "address" => db_instance.endpoint_address,
                "port" => db_instance.endpoint_port
            )
          end
        end

      else
        err "RDS was not available within 30 minutes, giving up"
      end

    ensure
      save_receipt("aws_rds_receipt", RdsDb.receipt)
    end
  end

  def deployment_properties(receipt)
    receipt.fetch('deployment_manifest', {}).fetch('properties', {})
  end

end

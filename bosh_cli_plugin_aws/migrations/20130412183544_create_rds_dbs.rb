class CreateRdsDbs < Bosh::AwsCliPlugin::Migration
  include Bosh::AwsCliPlugin::MigrationHelper

  def execute
    if !config["rds"]
      say "rds not set in config.  Skipping"
      return
    end

    vpc_receipt = load_receipt("aws_vpc_receipt")
    db_names   = %w(ccdb uaadb)
    db_configs = config['rds'].select {|c| db_names.include?(c['instance']) }
    RdsDb.aws_rds = rds
    dbs = []

    begin
      db_configs.each do |rds_db_conf|
        rds_args = { vpc_receipt: vpc_receipt, rds_db_conf: rds_db_conf }
        rds_db = RdsDb.new(rds_args)
        dbs << rds_db
        rds_db.create!
      end

      if RdsDb.was_rds_eventually_available?
        dbs.each { |db| db.update_receipt }
      else
        err "RDS was not available within 60 minutes, giving up"
      end

    ensure
      save_receipt("aws_rds_receipt", RdsDb.receipt)
    end
  end

end

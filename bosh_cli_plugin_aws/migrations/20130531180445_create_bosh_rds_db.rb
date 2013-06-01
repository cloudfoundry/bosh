class CreateBoshRdsDb < Bosh::Aws::Migration
  def execute
    puts ::Bosh::Aws::MigrationHelper.aws_migration_directory
    receipt = {}

    vpc_receipt = load_receipt("aws_vpc_receipt")
    vpc_subnets = vpc_receipt["vpc"]["subnets"]

      rds_db_config = config['rds'].find { |db| db['instance'] == 'bosh' }
      instance_id = rds_db_config["instance"]
      tag = rds_db_config["tag"]
      subnets = rds_db_config["subnets"]

      subnet_ids = subnets.map { |s| vpc_subnets[s] }

      unless rds.database_exists?(instance_id)
          creation_opts = [instance_id, subnet_ids, vpc_receipt["vpc"]["id"]]
        creation_opts << rds_db_config["aws_creation_options"] if rds_db_config["aws_creation_options"]
        response = rds.create_database(*creation_opts)
      end
    end

end

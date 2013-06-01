class CreateRdsDbs < Bosh::Aws::Migration

  class RdsDb

    attr_accessor :instance_id, :tag, :subnets, :subnet_ids

    def initialize(args = {})
      @aws_rds      = args.fetch(:aws_rds)
      @instance_id  = args.fetch(:instance_id)
      @tag          = args.fetch(:tag)
      @subnets      = args.fetch(:subnets)
      @subnet_ids   = args.fetch(:subnet_ids)
    end

   def create!
      return if @aws_rds.database_exists? @instance_id
      creation_opts = [@instance_id, @subnet_ids, vpc_receipt["vpc"]["id"]]

      if rds_db_config["aws_creation_options"]
        creation_opts << rds_db_config["aws_creation_options"]
      end

      response = @aws_rds.create_database(*creation_opts)
      output_rds_properties(receipt, instance_id, tag, response)

    end
  end

  def execute
    if !config["rds"]
      say "rds not set in config.  Skipping"
      return
    end

    receipt = {}

    vpc_receipt = load_receipt("aws_vpc_receipt")
    vpc_subnets = vpc_receipt["vpc"]["subnets"]


    begin
      config["rds"].each do |rds_db_conf|
        rds_args = {
            :instance_id => rds_db_conf["instance"],
            :tag         => rds_db_conf["tag"],
            :subnets     => rds_db_conf["subnets"],
            :subnet_ids  => subnets.map { |s| vpc_subnets[s],
            :vpc_receipt => vpc_receipt,
            :aws_rds     => rds
        }

        RdsDb.new(rds, rds_db_conf).create!
      end

      if was_rds_eventually_available?(rds)

        config["rds"].each do |rds_db_config|
          instance_id = rds_db_config["instance"]

          if deployment_properties(receipt)[instance_id]
            db_instance = rds.database(instance_id)
            receipt["deployment_manifest"]["properties"][instance_id].merge!(
                "address" => db_instance.endpoint_address,
                "port" => db_instance.endpoint_port
            )
          end
        end

      else
        err "RDS was not available within 30 minutes, giving up"
      end

    ensure
      save_receipt("aws_rds_receipt", receipt)
    end
  end

  private

  def was_rds_eventually_available?(rds)
    return true if all_rds_instances_available?(rds, :silent => true)
    (1..180).any? do |attempt|
      sleep 10
      all_rds_instances_available?(rds)
    end
  end

  def deployment_properties(receipt)
    receipt.fetch('deployment_manifest', {}).fetch('properties', {})
  end

  def output_rds_properties(receipt, name, tag, response)
    receipt["deployment_manifest"] ||= {}
    receipt["deployment_manifest"]["properties"] ||= {}
    receipt["deployment_manifest"]["properties"][name] = {
        "db_scheme" => response[:engine],
        "roles" => [
            {
                "tag" => "admin",
                "name" => response[:master_username],
                "password" => response[:master_user_password]
            }
        ],
        "databases" => [
            {
                "tag" => tag,
                "name" => name
            }
        ]
    }
  end
end

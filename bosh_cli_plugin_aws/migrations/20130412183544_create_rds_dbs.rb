class CreateRdsDbs < Bosh::Aws::Migration
  def execute
    if !config["rds"]
      say "rds not set in config.  Skipping"
      return
    end

    receipt = {}

    vpc_receipt = load_receipt("aws_vpc_receipt")
    vpc_subnets = vpc_receipt["vpc"]["subnets"]

    begin
      config["rds"].each do |rds_db_config|
        instance_id = rds_db_config["instance"]
        tag = rds_db_config["tag"]
        subnets = rds_db_config["subnets"]

        subnet_ids = subnets.map { |s| vpc_subnets[s] }
        unless rds.database_exists?(instance_id)
          # This is a bit odd, and the naturual way would be to just pass creation_opts
          # in directly, but it makes this easier to mock.  Once could argue that the
          # params to create_database should change to just a hash instead of a name +
          # a hash.
          creation_opts = [instance_id, subnet_ids, vpc_receipt["vpc"]["id"]]
          creation_opts << rds_db_config["aws_creation_options"] if rds_db_config["aws_creation_options"]
          response = rds.create_database(*creation_opts)
          output_rds_properties(receipt, instance_id, tag, response)
        end
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


  def all_rds_instances_available?(rds, opts = {})
    silent = opts[:silent]
    say("checking rds status...") unless silent
    rds.databases.all? do |db_instance|
      say("  #{db_instance.db_name} #{db_instance.db_instance_status} #{db_instance.endpoint_address}") unless silent
      !db_instance.endpoint_address.nil?
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

class CreateRdsDbs < Bosh::Aws::Migration

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

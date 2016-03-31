require 'securerandom'

module Bosh::Deployer
  class DeploymentsState

    DEPLOYMENTS_FILE = 'bosh-deployments.yml'

    attr_reader :file, :deployments, :state

    def self.load_from_dir(dir, logger)
      file = File.join(dir, DEPLOYMENTS_FILE)
      if File.exists?(file)
        logger.info("Loading existing deployment data from: #{file}")
        deployments = Psych.load_file(file)
      else
        logger.info("No existing deployments found (will save to #{file})")
        deployments = { 'instances' => [], 'disks' => [] }
      end
      new(deployments, file)
    end

    def initialize(deployments, file)
      @deployments = deployments
      @file = file
    end

    def load_deployment(name)
      models_instance.multi_insert(deployments['instances'])

      @state = models_instance.find(name: name)
      if state.nil?
        @state = models_instance.new
        state.uuid = "bm-#{SecureRandom.uuid}"
        state.name = name
        state.stemcell_sha1 = nil
        state.save
      end
    end

    def save(infrastructure)
      state.save
      deployments['instances'] = models_instance.map { |instance| instance.values }

      File.open(file, 'w') do |file|
        file.write(Psych.dump(deployments))
      end
    end

    def exists?
      return false unless state
      [state.vm_cid, state.stemcell_cid, state.disk_cid].any?
    end

    private

    def models_instance
      Models::Instance
    end
  end
end


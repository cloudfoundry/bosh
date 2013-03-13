module Bosh::AwsCloud
  class ResourceWait

    DEFAULT_TRIES = 10
    MAX_SLEEP_EXPONENT = 8

    def self.for_instance(args)
      raise ArgumentError, "args should be a Hash, but `#{args.class}' given" unless args.is_a?(Hash)
      instance = args.fetch(:instance) { raise ArgumentError, 'instance object required' }
      target_state = args.fetch(:state) { raise ArgumentError, 'state symbol required' }
      valid_states = [:running, :terminated]
      validate_states(valid_states, target_state)

      ignored_errors = [AWS::EC2::Errors::InvalidInstanceID::NotFound]

      new.for_resource(resource: instance, errors: ignored_errors, target_state: target_state) do |current_state|
        if target_state == :running && current_state == :terminated
          logger.error("instance #{instance.id} terminated while starting")
          raise Bosh::Clouds::VMCreationFailed.new(true)
        else
          current_state == target_state
        end
      end
    end

    def self.for_attachment(args)
      attachment = args.fetch(:attachment) { raise ArgumentError, 'attachment object required' }
      target_state = args.fetch(:state) { raise ArgumentError, 'state symbol required' }
      valid_states = [:attached, :detached]
      validate_states(valid_states, target_state)

      new.for_resource(resource: attachment, target_state: target_state, description: attachment.to_s) do |current_state|
        current_state == target_state
      end
    rescue AWS::Core::Resource::NotFound
      # if an attachment is detached, AWS can reap the object and the reference is no longer found,
      # so consider this exception a success condition if we are detaching
      raise unless target_state == :detached
    end

    def self.for_image(args)
      image = args.fetch(:image) { raise ArgumentError, 'image object required' }
      target_state = args.fetch(:state) { raise ArgumentError, 'state symbol required' }
      valid_states = [:available, :deleted]
      validate_states(valid_states, target_state)

      if target_state == :available
        ignored_errors = [AWS::EC2::Errors::InvalidAMIID::NotFound]
      else
        ignored_errors = []
      end

      new.for_resource(resource: image, errors: ignored_errors, target_state: target_state, state_method: :state) do |current_state|
        current_state == target_state
      end
    end

    def self.for_volume(args)
      volume = args.fetch(:volume) { raise ArgumentError, 'volume object required' }
      target_state = args.fetch(:state) { raise ArgumentError, 'state symbol required' }
      valid_states = [:available, :deleted]
      validate_states(valid_states, target_state)

      new.for_resource(resource: volume, target_state: target_state) do |current_state|
        current_state == target_state
      end
    rescue AWS::EC2::Errors::InvalidVolume::NotFound
      # if an volume is deleted, AWS can reap the object and the reference is no longer found,
      # so consider this exception a success condition if we are deleting
      raise unless target_state == :deleted
    end

    def self.for_snapshot(args)
      snapshot = args.fetch(:snapshot) { raise ArgumentError, 'snapshot object required' }
      target_state = args.fetch(:state) { raise ArgumentError, 'state symbol required' }
      valid_states = [:completed]
      validate_states(valid_states, target_state)

      new.for_resource(resource: snapshot, target_state: target_state) do |current_state|
        current_state == target_state
      end
    end

    def self.validate_states(valid_states, target_state)
      unless valid_states.include?(target_state)
        raise ArgumentError, "target state must be one of #{valid_states.join(', ')}, `#{target_state}' given"
      end
    end

    def self.logger
      Bosh::Clouds::Config.logger
    end

    def initialize
      @started_at = Time.now
    end

    def for_resource(args)
      resource = args.fetch(:resource)
      state_method = args.fetch(:state_method, :status)
      errors = args.fetch(:errors, [])
      desc = args.fetch(:description) { resource.id }
      tries = args.fetch(:tries, DEFAULT_TRIES).to_i
      target_state = args.fetch(:target_state)

      errors << AWS::EC2::Errors::RequestLimitExceeded

      sleep_cb = lambda do |num_tries, error|
        sleep_time = 2**[num_tries,MAX_SLEEP_EXPONENT].min # Exp backoff: 1, 2, 4, 8 ... up to max 256
        Bosh::AwsCloud::ResourceWait.logger.debug("#{error.class}: `#{error.message}'") if error
        Bosh::AwsCloud::ResourceWait.logger.debug("Retrying in #{sleep_time} seconds")
        sleep_time
      end

      ensure_cb = Proc.new do |retries|
        cloud_error("Timed out waiting for #{desc} to be #{target_state}") if retries == tries
      end

      state = nil
      Bosh::Common.retryable(tries: tries, sleep: sleep_cb, on: errors, ensure: ensure_cb ) do
        Bosh::AwsCloud::ResourceWait.task_checkpoint # from config
        state = resource.call(state_method)

        if state == :error || state == :failed
          raise Bosh::Clouds::CloudError, "#{desc} state is #{state}, expected #{target_state}"
        end

        # the yielded block should return true if we have reached the target state
        yield state
      end

      Bosh::AwsCloud::ResourceWait.logger.info("#{desc} is now #{state}, took #{time_passed}s")
    end

    def time_passed
      Time.now - @started_at
    end

    def self.task_checkpoint
      Bosh::Clouds::Config.task_checkpoint
    end
  end
end


# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Director
  class DeploymentPlan
    ##
    # Represents a single job instance.
    class InstanceSpec
      include DnsHelper

      # @return [JobSpec] associated job
      attr_accessor :job

      # @return [Integer] associated deployment
      attr_accessor :index

      # @return [Bosh::Director::Models::Instance] associated model
      attr_accessor :instance

      # @return [String] SHA1 hash of all of the configuration templates
      attr_accessor :configuration_hash

      # @return [Hash] A hash of template SHA1 hashes.
      attr_accessor :template_hashes

      # @return [Hash<String, NetworkReservation>] network reservations
      attr_accessor :network_reservations

      # @return [String] job state
      # @todo rename since it's confusing with current_state and is sometimes a
      #    verb
      attr_accessor :state

      # @return [Hash] current state as provided by the BOSH Agent
      attr_accessor :current_state

      # @return [IdleVm] associated resource pool VM if it hasn't been bound yet
      attr_accessor :idle_vm

      # @return [Boolean] true if this instance needs to be recreated
      attr_accessor :recreate

      # @return [Boolean] true if this instance needs to be restarted
      attr_accessor :restart

      ##
      # Creates a new instance specification based on the job and index.
      #
      # @param [JobSpec] job associated job
      # @param [Integer] index index for this instance
      def initialize(job, index)
        @job = job
        @index = index
        @network_reservations = {}
        @state = job.instance_states[index] || job.state

        # Expanding virtual states
        case @state
          when "recreate"
            @recreate = true
            @state = "started"
          when "restart"
            @restart = true
            @state = "started"
        end
      end

      ##
      # Adds a new network to this instance
      # @param [String] name network name
      # @param [NetworkReservation] reservation
      def add_network_reservation(name, reservation)
        old_reservation = @network_reservations[name]

        if old_reservation
          raise NetworkReservationAlreadyExists,
                "`#{@job}/#{@index}' already has reservation " +
                "for network `#{name}', IP #{old_reservation.ip}"
        end
        @network_reservations[name] = reservation
      end

      ##
      # Take any existing valid network reservations
      #
      # @param [Hash<String, NetworkReservation] reservations
      # @return [void]
      def take_network_reservations(reservations)
        reservations.each do |name, provided_reservation|
          reservation = @network_reservations[name]
          reservation.take(provided_reservation) if reservation
        end
      end

      ##
      # @return [Hash] BOSH network settings used for Agent apply call
      def network_settings
        default_properties = {}
        @job.default_network.each do |key, value|
          (default_properties[value] ||= []) << key
        end

        network_settings = {}
        @network_reservations.each do |name, reservation|
          network = @job.deployment.network(name)
          network_settings[name] = network.network_settings(
              reservation, default_properties[name])

          # Somewhat of a hack: for dynamic networks we might know IP address
          # if it's featured in agent state, in that case we put it into
          # network spec to satisfy ConfigurationHasher in both agent
          # and director.
          if @current_state.is_a?(Hash) &&
              @current_state["networks"].is_a?(Hash) &&
              @current_state["networks"][name].is_a?(Hash) &&
              network_settings[name]["type"] == "dynamic"
            network_settings[name] = @current_state["networks"][name]
          end
        end
        network_settings
      end

      ##
      # @return [Integer] persistent disk size
      def disk_size
        if @instance.nil?
          current_state["persistent_disk"].to_i
        elsif @instance.persistent_disk
          @instance.persistent_disk.size
        else
          0
        end
      end

      ##
      # @return [Hash<String, String>] dns record hash
      def dns_records
        return @dns_records if @dns_records
        @dns_records = {}
        network_settings.each do |network_name, network|
          name = [index, job.canonical_name, canonical(network_name),
                  job.deployment.canonical_name, :bosh].join(".")
          @dns_records[name] = network["ip"]
        end
        @dns_records
      end

      ##
      # @return [Boolean] returns true if the persistent disk is attached to the
      #   VM
      def disk_currently_attached?
        current_state["persistent_disk"].to_i > 0
      end

      ##
      # @return [Boolean] returns true if the network configuration changed
      def networks_changed?
        network_settings != @current_state["networks"]
      end

      ##
      # @return [Boolean] returns true if the expected resource pool differs
      #   from the one provided by the VM
      def resource_pool_changed?
        @recreate ||
            @job.deployment.recreate ||
            @job.resource_pool.spec != @current_state["resource_pool"]
      end

      ##
      # @return [Boolean] returns true if the expected configuration hash
      #   differs from the one provided by the VM
      def configuration_changed?
        configuration_hash != @current_state["configuration_hash"]
      end

      ##
      # @return [Boolean] returns true if the expected job configuration differs
      #   from the one provided by the VM
      def job_changed?
        @job.spec != @current_state["job"]
      end

      ##
      # @return [Boolean] returns true if the expected packaged of the running
      #   instance differ from the ones provided by the VM
      def packages_changed?
        @job.package_spec != @current_state["packages"]
      end

      ##
      # @return [Boolean] returns true if the expected persistent disk differs
      #   from the one currently configured on the VM
      def persistent_disk_changed?
        @job.persistent_disk != disk_size
      end

      ##
      # @return [Boolean] returns true if the DNS records configured for the
      #   instance differ from the ones configured on the DNS server
      def dns_changed?
        if Config.dns_enabled?
          dns_records.any? do |name, ip|
            Models::Dns::Record.find(:name => name, :type => "A",
                                     :content => ip).nil?
          end
        else
          false
        end
      end

      ##
      # Checks if agent view of the instance state is consistent with target
      # instance state.
      #
      # In case the instance current state is 'detached' we should never get to
      # this method call.
      # @return [Boolean] returns true if the expected job state differs from
      #   the one provided by the VM
      def state_changed?
        @state == "detached" ||
            @state == "started" && @current_state["job_state"] != "running" ||
            @state == "stopped" && @current_state["job_state"] == "running"
      end

      ##
      # @return [Boolean] returns true if the any of the expected specifications
      #   differ from the ones provided by the VM
      def changed?
        !changes.empty?
      end

      ##
      # @return [Set<Symbol>] returns a set of all of the specification
      #   differences
      def changes
        changes = Set.new
        unless @state == "detached" && @current_state.nil?
          changes << :restart if @restart
          changes << :resource_pool if resource_pool_changed?
          changes << :network if networks_changed?
          changes << :packages if packages_changed?
          changes << :persistent_disk if persistent_disk_changed?
          changes << :configuration if configuration_changed?
          changes << :job if job_changed?
          changes << :state if state_changed?
          changes << :dns if dns_changed?
        end
        changes
      end

      ##
      # Instance spec that's passed to the VM during the BOSH Agent apply call.
      # It's what's used for comparing the expected vs the actual state.
      #
      # @return [Hash<String, Object>] instance spec
      def spec
        deployment_plan = @job.deployment
        spec = {
            "deployment" => deployment_plan.name,
            "release" => job.release.spec,
            "job" => job.spec,
            "index" => index,
            "networks" => network_settings,
            "resource_pool" => job.resource_pool.spec,
            "packages" => job.package_spec,
            "persistent_disk" => job.persistent_disk,
            "configuration_hash" => configuration_hash,
            "properties" => job.properties
        }
        spec["template_hashes"] = template_hashes unless template_hashes.nil?
        spec
      end
    end
  end
end

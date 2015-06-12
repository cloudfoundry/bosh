module Bosh::Director
  # A class for storing VMs and their associated data so that they can be
  # accessed and deleted easily.
  class VmData

    # @attr [NetworkReservation] The network reservation for this VM.
    attr_reader :reservation

    # @attr [Models::Vm] The VM.
    attr_reader :vm

    # @attr[Models::Stemcell] The Stemcell this VM is running.
    attr_reader :stemcell

    # @attr [Hash] A hash containing the network reservation.
    attr_reader :network_settings

    # @attr [Integer] The agent ID running on this VM.
    attr_reader :agent_id

    # @attr [AgentClient] The agent running on this VM.
    attr_accessor :agent

    # Initializes a VmData.
    # @param [NetworkReservation] reservation The network reservation for this VM.
    # @param [Models::Vm] vm The VM to be reused.
    # @param [Models::Stemcell] stemcell The Stemcell to make the VM on.
    # @param [Hash] network_settings A hash containing the network reservation.
    def initialize(reservation, vm, stemcell, network_settings)
      @reservation = reservation
      @vm = vm
      @stemcell = stemcell
      @network_settings = network_settings
      @agent_id = vm.agent_id
      @agent = nil
    end

    def agent
      @agent ||= AgentClient.with_defaults(vm.agent_id)
    end
  end
end

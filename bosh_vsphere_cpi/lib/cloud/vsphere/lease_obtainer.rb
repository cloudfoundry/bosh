require 'ruby_vim_sdk'

module VSphereCloud
  class LeaseObtainer
    include VimSdk

    def initialize(client, logger)
      @client = client
      @logger = logger
    end

    def obtain(resource_pool, import_spec, template_folder)
      @logger.info('Importing VApp')
      nfc_lease = resource_pool.mob.import_vapp(import_spec, template_folder.mob, nil)

      @logger.info('Waiting for NFC lease to become ready')
      state = wait_for_nfc_lease(nfc_lease)

      if state == Vim::HttpNfcLease::State::ERROR
        raise_nfc_lease_error(nfc_lease)
      end

      if state != Vim::HttpNfcLease::State::READY
        raise "Could not acquire HTTP NFC lease (state is: '#{state}')"
      end

      nfc_lease
    end

    private

    def wait_for_nfc_lease(nfc_lease)
      loop do
        state = @client.get_property(nfc_lease, Vim::HttpNfcLease, 'state')
        return state unless state == Vim::HttpNfcLease::State::INITIALIZING
        sleep(1.0)
      end
    end

    def raise_nfc_lease_error(nfc_lease)
      error = @client.get_property(nfc_lease, Vim::HttpNfcLease, 'error')
      raise "Could not acquire HTTP NFC lease, message is: '#{error.msg}' " +
              "fault cause is: '#{error.fault_cause}', " +
              "fault message is: #{error.fault_message}, " +
              "dynamic type is '#{error.dynamic_type}', " +
              "dynamic property is #{error.dynamic_property}"
    end
  end
end

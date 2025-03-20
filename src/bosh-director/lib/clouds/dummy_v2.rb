require 'digest/sha1'
require 'fileutils'
require 'securerandom'
require 'membrane'
require_relative '../clouds/errors'

module Bosh
  module Clouds
    class DummyV2 < Bosh::Clouds::Dummy

      def initialize(options, context)
        super(options, context, 2)
      end

      # rubocop:disable ParameterLists
      def create_vm(agent_id, stemcell_id, cloud_properties, networks, disk_cids, env)
        vm_cid = Dummy.instance_method(:create_vm).bind(self).call(agent_id, stemcell_id, cloud_properties, networks, disk_cids, env)

        [
          vm_cid,
          {},
        ]
      end

      ATTACH_DISK_SCHEMA = Membrane::SchemaParser.parse { { vm_cid: String, disk_id: String } }
      def attach_disk(vm_cid, disk_id)
        validate_and_record_inputs(ATTACH_DISK_SCHEMA, __method__, vm_cid, disk_id)
        raise "#{disk_id} is already attached to an instance" if disk_attached?(disk_id)
        file = attachment_file(vm_cid, disk_id)
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.touch(file)

        @logger.debug("Attached disk: '#{disk_id}' to vm: '#{vm_cid}' at attachment file: #{file}")

        agent_id = agent_id_for_vm_id(vm_cid)
        settings = read_agent_settings(agent_id)
        settings['disks']['persistent'][disk_id] = 'attached'
        write_agent_settings(agent_id, settings)
        file
      end

      def info
        record_inputs(__method__, nil)
        {
          api_version: 2,
          stemcell_formats: @supported_formats,
        }
      end
    end
  end
end

require "spec_helper"
require "tempfile"
require "cloud"
require "logger"

describe Bosh::OpenStackCloud::Cloud do
  before(:all) do
    @auth_url    = ENV['BOSH_OPENSTACK_AUTH_URL']    || raise("Missing BOSH_OPENSTACK_AUTH_URL")
    @username    = ENV['BOSH_OPENSTACK_USERNAME']    || raise("Missing BOSH_OPENSTACK_USERNAME")
    @api_key     = ENV['BOSH_OPENSTACK_API_KEY']     || raise("Missing BOSH_OPENSTACK_API_KEY")
    @tenant      = ENV['BOSH_OPENSTACK_TENANT']      || raise("Missing BOSH_OPENSTACK_TENANT")
    @region      = ENV['BOSH_OPENSTACK_REGION']      || raise("Missing BOSH_OPENSTACK_REGION")
    @stemcell_id = ENV['BOSH_OPENSTACK_STEMCELL_ID'] || raise("Missing BOSH_OPENSTACK_STEMCELL_ID")
    @net_id      = ENV['BOSH_OPENSTACK_NET_ID']      || raise("Missing BOSH_OPENSTACK_NET_ID")
    @manual_ip   = ENV['BOSH_OPENSTACK_MANUAL_IP']   || raise("Missing BOSH_OPENSTACK_MANUAL_IP")
  end

  subject(:cpi) do
    described_class.new(
      "openstack" => {
        "auth_url" => @auth_url,
        "username" => @username,
        "api_key" => @api_key,
        "tenant" => @tenant,
        "region" => @region,
        "endpoint_type" => "publicURL",
        "default_key_name" => "jenkins",
        "default_security_groups" => ["default"]
      },
      "registry" => {
        "endpoint" => "fake",
        "user" => "fake",
        "password" => "fake"
      }
    )
  end

  before do
    delegate = double("delegate", task_checkpoint: nil, logger: logger)
    Bosh::Clouds::Config.configure(delegate)
  end

  before { Bosh::Clouds::Config.stub(logger: logger) }
  let(:logger) { Logger.new(STDERR) }

  before { Bosh::Registry::Client.stub(new: double("registry").as_null_object) }

  describe "dynamic network" do
    let(:network_spec) do
      {
        "default" => {
          "type" => "dynamic",
          "cloud_properties" => {}
        }
      }
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(@stemcell_id, network_spec, [])
      end
    end

    context "with existing disks" do
      before { @existing_volume_id = cpi.create_disk(2048) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it "should exercise the vm lifecycle" do
        vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
      end
    end
  end

  describe "manual network" do
    let(:network_spec) do
      {
        "default" => {
          "type" => "manual",
          "ip" => @manual_ip,
          "cloud_properties" => {
            "net_id" => @net_id
          }
        }
      }
    end

    context "without existing disks" do
      it "should exercise the vm lifecycle" do
        vm_lifecycle(@stemcell_id, network_spec, [])
      end
    end

    context "with existing disks" do
      before { @existing_volume_id = cpi.create_disk(2048) }
      after { cpi.delete_disk(@existing_volume_id) if @existing_volume_id }

      it "should exercise the vm lifecycle" do
        # Sometimes Quantum is too slow to release an IP address, so when we
        # spin up a new vm reusing the same IP it fails with a vm state error
        # but without any clue what the problem is (you should check the nova log).
        # This should be removed once we figure out how to deal with this situation.
        sleep(120)
        vm_lifecycle(@stemcell_id, network_spec, [@existing_volume_id])
      end
    end
  end

  def vm_lifecycle(stemcell_id, network_spec, disk_locality)
    vm_id = create_vm(stemcell_id, network_spec, disk_locality)
    disk_id = create_disk(vm_id)
    disk_snapshot_id = create_disk_snapshot(disk_id)
  rescue Exception => create_error
  ensure
    # create_error is in scope and possibly populated!
    run_all_and_raise_any_errors(create_error, [
      lambda { clean_up_disk_snapshot(disk_snapshot_id) },
      lambda { clean_up_disk(disk_id) },
      lambda { clean_up_vm(vm_id) },
    ])
  end

  def create_vm(stemcell_id, network_spec, disk_locality)
    logger.info("Creating VM with stemcell_id=#{stemcell_id}")
    vm_id = cpi.create_vm(
      "agent-007",
      stemcell_id,
      { "instance_type" => "m1.small" },
      network_spec,
      disk_locality,
      { "key" => "value" }
    )
    vm_id.should_not be_nil

    logger.info("Checking VM existence vm_id=#{vm_id}")
    cpi.has_vm?(vm_id).should be(true)

    logger.info("Setting VM metadata vm_id=#{vm_id}")
    cpi.set_vm_metadata(vm_id, {
      :deployment => 'deployment',
      :job => 'openstack_cpi_spec',
      :index => '0',
    })

    vm_id
  end

  def clean_up_vm(vm_id)
    if vm_id
      logger.info("Deleting VM vm_id=#{vm_id}")
      cpi.delete_vm(vm_id)

      logger.info("Checking VM existence vm_id=#{vm_id}")
      cpi.has_vm?(vm_id).should be(false)
    else
      logger.info("No VM to delete")
    end
  end

  def create_disk(vm_id)
    logger.info("Creating disk for VM vm_id=#{vm_id}")
    disk_id = cpi.create_disk(2048, vm_id)
    disk_id.should_not be_nil

    logger.info("Attaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
    cpi.attach_disk(vm_id, disk_id)

    logger.info("Detaching disk vm_id=#{vm_id} disk_id=#{disk_id}")
    cpi.detach_disk(vm_id, disk_id)

    disk_id
  end

  def clean_up_disk(disk_id)
    if disk_id
      logger.info("Deleting disk disk_id=#{disk_id}")
      cpi.delete_disk(disk_id)
    else
      logger.info("No disk to delete")
    end
  end

  def create_disk_snapshot(disk_id)
    logger.info("Creating disk snapshot disk_id=#{disk_id}")
    disk_snapshot_id = cpi.snapshot_disk(disk_id, {
      :deployment => 'deployment',
      :job => 'openstack_cpi_spec',
      :index => '0',
      :instance_id => 'instance',
      :agent_id => 'agent',
      :director_name => 'Director',
      :director_uuid => '6d06b0cc-2c08-43c5-95be-f1b2dd247e18',
    })
    disk_snapshot_id.should_not be_nil

    logger.info("Created disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
    disk_snapshot_id
  end

  def clean_up_disk_snapshot(disk_snapshot_id)
    if disk_snapshot_id
      logger.info("Deleting disk snapshot disk_snapshot_id=#{disk_snapshot_id}")
      cpi.delete_snapshot(disk_snapshot_id)
    else
      logger.info("No disk snapshot to delete")
    end
  end

  def run_all_and_raise_any_errors(existing_errors, funcs)
    exceptions = Array(existing_errors)
    funcs.each do |f|
      begin
        f.call
      rescue Exception => e
        exceptions << e
      end
    end
    # Prints all exceptions but raises original exception
    exceptions.each { |e| logger.info("Failed with: #{e.inspect}\n#{e.backtrace.join("\n")}\n") }
    raise exceptions.first if exceptions.any?
  end
end

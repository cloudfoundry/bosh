require File.dirname(__FILE__) + "/../spec_helper"
require "yaml"

module VCloudCloud
  module UnitTest
    AGENT_ENV = %q[{"vm":{"name":"vm-8715dc0d-0270-4679-8429-6b90090bab58","id":
"vm-793"},"agent_id":"1a8ad1aa-4b28-4483-be81-9c45f1d2f071","networks":{
"default":{"ip":"10.147.130.80","netmask":"255.255.255.192","cloud_properties":{
"name":"VC-10.47.24.204-vcd-external"},"default":["dns","gateway"],"dns":[
"10.147.115.1","10.147.115.2"],"gateway":"10.147.130.126","mac":
"00:50:56:9a:44:d8"}},"disks":{"system":0,"persistent":{}},"ntp":[
"ntp01.las01.emcatmos.com"],"blobstore":{"plugin":"simple","properties":{
"endpoint":"http://10.147.130.68:25250","user":"agent","password":"Ag3Nt"}},
"mbus":"nats://bosh:b0$H@10.147.130.68:4222","env":{}}]
    AGENT_ENV_WITH_PERSITENT_DISK = %q[{"vm":{"name":
"vm-8715dc0d-0270-4679-8429-6b90090bab58","id":"vm-793"},"agent_id":
"1a8ad1aa-4b28-4483-be81-9c45f1d2f071","networks":{"default":{
"ip":"10.147.130.80","netmask":"255.255.255.192","cloud_properties":{"name":
"VC-10.47.24.204-vcd-external"},"default":["dns","gateway"],"dns":[
"10.147.115.1","10.147.115.2"],"gateway":"10.147.130.126","mac":
"00:50:56:9a:44:d8"}},"disks":{"system":0,"ephemeral":1, "persistent":{
"test_disk":1}},"ntp":["ntp01.las01.emcatmos.com"],"blobstore":{"plugin":
"simple","properties":{"endpoint":"http://10.147.130.68:25250","user":"agent",
"password":"Ag3Nt"}},"mbus":"nats://bosh:b0$H@10.147.130.68:4222","env":{}}]

    class CatalogItem
      def urn
        "urn:vcloud:catalogitem:0bed5661-6fef-43e8-aaae-973783efc5cb"
      end
    end

    class VApp
      def vms
        @vms
      end
      def name
        "myTestVapp"
      end
      def initialize
        @vms = Array[ Vm.new ]
      end
      def urn
        "urn:vcloud:vapp:a1da3521-71aa-480b-97f4-2fdc2ce48569"
      end
    end

    class Network
      def initialize(name)
        @name = name
      end

      def [](p)
        @name
      end
    end

    class Vdc
      attr_accessor :name

      def initialize(name)
        @name = name
      end

      def available_networks
        [Network.new("a"), Network.new("vcd-org-network")]
      end

      def storage_profiles
        #[Network.new("a"), Network.new("vcd-org-network")]
      end
    end

    class Vm
      class Nic
        def network
          VCloudCloud::Test::test_deployment_manifest[
            "network"]["default"]["cloud_properties"]["name"]
        end
        def mac_address
          "00:50:56:de:ad:ff"
        end
      end

      class HardDisk
        attr_accessor :disk_id

        def initialize(disk_id)
          @disk_id = disk_id
        end

        def urn
          "urn:vcloud:disk:a1da3521-71aa-480b-97f4-2fdc2ce48569"
        end

        def size_mb
          1073741824.to_i/1024/1024
        end
      end

      class HwSec
        def nics
          Array[ Nic.new ]
        end
        def hard_disks
          @disks
        end
        def initialize
          @disks = [ HardDisk.new(0) ]
        end
        def add_hard_disk
          disk =  HardDisk.new(@disks.size)
          @disks << disk
        end
        def del_hard_disk
          disk = @disks.pop
        end
      end

      def hardware_section
        @hw
      end

      def urn
        "urn:vcloud:vm:a1da3521-71aa-480b-97f4-2fdc2ce48569"
      end

      def name
        "myTestVm"
      end

      def name=(value)
        "myTestVm"
      end

      def description=(value)
        "myTestVm"
      end

      def initialize
        @hw = HwSec.new
      end

      def add_hard_disk
        @hw.add_hard_disk
      end

      def del_hard_disk
        @hw.del_hard_disk
      end
    end

  end
end

module VCloudCloud
  vcd_settings = VCloudCloud::Test::vcd_settings
  cloud_properties = VCloudCloud::Test::director_cloud_properties
  test_manifest = VCloudCloud::Test::test_deployment_manifest

  describe Cloud, :min, :all do

    it "can upload a valid stemcell" do
      mc = mock("client")
      mc.should_receive(:upload_vapp_template).with(an_instance_of(String),
        an_instance_of(String)).and_return { UnitTest::CatalogItem.new }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.create_stemcell(Test::spec_asset("valid_stemcell.tgz"), {})
    end

    it "can delete a stemcell" do
      mc = mock("client")
      mc.should_receive(:delete_catalog_vapp).with(
        an_instance_of(String)).and_return {}

      cloud= VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.delete_stemcell("test_stemcell_name")
    end

    it "can create a vm" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:upload_vapp_template).with(an_instance_of(String),
        an_instance_of(String)).and_return { UnitTest::CatalogItem.new }
      mc.should_receive(:instantiate_vapp_template).with(an_instance_of(String),
        an_instance_of(String), an_instance_of(String), anything).and_return {
          vapp }
      mc.should_receive(:power_on_vapp).with(anything).and_return {}
      mc.should_receive(:get_ovdc).at_least(:once).with().and_return {
        UnitTest::Vdc.new("myOvdc") }
      mc.should_receive(:add_network).with(anything, anything).and_return {}
      mc.should_receive(:delete_networks).with(anything, anything).and_return {}
      mc.should_receive(:reconfigure_vm).with(anything).and_return {
        vapp.vms[0].add_hard_disk }
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return { raise VCloudSdk::CatalogMediaNotFoundError,
          "ISO by name not found" }
      mc.should_receive(:upload_catalog_media).with(
        an_instance_of(String), an_instance_of(String), anything).and_return {}
      mc.should_receive(:insert_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:eject_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:get_vapp).at_least(:once).with(anything).and_return {
        vapp }
      mc.should_receive(:set_metadata).with(anything, an_instance_of(String),
        an_instance_of(String)).and_return {}

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      stemcell = cloud.create_stemcell(Test::spec_asset("valid_stemcell.tgz"),
        {})
      cloud.create_vm(Test::generate_unique_name, stemcell,
        test_manifest["resource_pools"][0]["cloud_properties"],
        test_manifest["network"])
    end

    it "can create a vm with disk locality" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:upload_vapp_template).with(an_instance_of(String),
        an_instance_of(String)).and_return { UnitTest::CatalogItem.new() }
      mc.should_receive(:instantiate_vapp_template).with(an_instance_of(String),
        an_instance_of(String), an_instance_of(String), anything).and_return {
          vapp }
      mc.should_receive(:reconfigure_vm).with(anything).and_return {
        vapp.vms[0].add_hard_disk }
      mc.should_receive(:power_on_vapp).with(anything).and_return {}
      mc.should_receive(:get_ovdc).at_least(:once).with().and_return {
        UnitTest::Vdc.new("myOvdc") }
      mc.should_receive(:add_network).with(anything, anything).and_return {}
      mc.should_receive(:delete_networks).with(anything, anything).and_return {}
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return { raise VCloudSdk::CatalogMediaNotFoundError,
          "ISO by name not found" }
      mc.should_receive(:upload_catalog_media).with(an_instance_of(String),
        an_instance_of(String), anything).and_return {}
      mc.should_receive(:insert_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:eject_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:get_vapp).at_least(:once).with(anything).and_return {
        vapp }
      mc.should_receive(:set_metadata).with(anything, an_instance_of(String),
        an_instance_of(String)).and_return {}
      mc.should_receive(:get_disk).twice.with(an_instance_of(
        String)).and_return { vapp.vms[0].hardware_section.hard_disks.last }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      disk_locality = []
      disk_locality << "test_disk_id"
      disk_locality << "test_disk_id_non_existent"
      stemcell = cloud.create_stemcell(Test::spec_asset("valid_stemcell.tgz"),
        {})
      cloud.create_vm(Test::generate_unique_name, stemcell,
        test_manifest["resource_pools"][0]["cloud_properties"],
        test_manifest["network"], disk_locality)
    end

    it "can delete a vm" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).with(anything).and_return { vapp }
      mc.should_receive(:power_off_vapp).with(vapp).and_return {}
      mc.should_receive(:delete_vapp).with(vapp).and_return {} if
        vcd_settings["debug"]["delete_vapp"] == true
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return {}

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.delete_vm(vapp.name)
    end

    it "can delete a suspended vm" do
      vapp_power_state = "suspended"
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).with(anything).and_return { vapp }
      mc.should_receive(:discard_suspended_state_vapp).with(
        anything).and_return { vapp }
      mc.should_receive(:power_off_vapp).at_least(:once).with(vapp).and_return {
        if vapp_power_state == "suspended"
          vapp_power_state = "off"
          raise VCloudSdk::VappSuspendedError
        end
      }
      mc.should_receive(:delete_vapp).with(vapp).and_return {} if
        vcd_settings["debug"]["delete_vapp"] == true
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return {}

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.delete_vm(vapp.name)
    end

    it "can reboot a vm" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).with(anything).and_return { vapp }
      mc.should_receive(:reboot_vapp).with(vapp).and_return {}

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.reboot_vm(vapp.name)
    end

    it "can reboot a powered off vm" do
      vapp_power_state = "off"
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).with(anything).and_return { vapp }
      mc.should_receive(:power_on_vapp).with(vapp).and_return {}
      mc.should_receive(:reboot_vapp).at_least(:once).with(vapp).and_return {
        if vapp_power_state == "off"
          vapp_power_state = "on"
          raise VCloudSdk::VappPoweredOffError
        end
      }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.reboot_vm(vapp.name)
    end

    it "can reboot a suspended vm" do
      vapp_power_state = "suspended"
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).with(anything).and_return { vapp }
      mc.should_receive(:discard_suspended_state_vapp).with(
        anything).and_return { vapp }
      mc.should_receive(:power_on_vapp).with(vapp).and_return {}
      mc.should_receive(:reboot_vapp).at_least(:once).with(vapp).and_return {
        if vapp_power_state == "suspended"
          vapp_power_state = "on"
          raise VCloudSdk::VappSuspendedError
        end
      }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.reboot_vm(vapp.name)
    end

    it "can re-configure vm networks" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).at_least(:once).with(
        anything).and_return { vapp }
      mc.should_receive(:power_off_vapp).with(vapp).and_return {}
      mc.should_receive(:power_on_vapp).with(anything).and_return {}
      mc.should_receive(:reconfigure_vm).with(anything).and_return {}
      mc.should_receive(:get_ovdc).at_least(:once).with().and_return {
        UnitTest::Vdc.new("myOvdc") }
      mc.should_receive(:delete_networks).with(anything, anything).and_return {}
      mc.should_receive(:add_network).with(anything, anything).and_return {}
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return {}
      mc.should_receive(:upload_catalog_media).with(an_instance_of(String),
        an_instance_of(String), anything).and_return {}
      mc.should_receive(:insert_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:eject_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:set_metadata).with(anything, an_instance_of(String),
        an_instance_of(String)).and_return {}
      mc.should_receive(:get_metadata).with(anything,
        an_instance_of(String)).and_return { UnitTest::AGENT_ENV }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.configure_networks(vapp.name, test_manifest["network"])
    end

    it "can create a disk without locality" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:create_disk).with(
        an_instance_of(String), an_instance_of(Fixnum)).and_return {
          vapp.vms[0].hardware_section.hard_disks.last }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.create_disk(4096)
    end

    it "can create a disk with locality" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).with(anything).and_return { vapp }
      mc.should_receive(:create_disk).with(
        an_instance_of(String), an_instance_of(Fixnum), anything).and_return {
          vapp.vms[0].hardware_section.hard_disks.last }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.create_disk(4096, vapp.name)
    end

    it "can delete a disk" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:delete_disk).any_number_of_times.with(
        anything).and_return {}
      mc.should_receive(:get_disk).with(an_instance_of(String)).and_return {
        vapp.vms[0].hardware_section.hard_disks.last }

      cloud= VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.delete_disk("test_disk_id")
    end

    it "can attach a disk to a vm" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).at_least(:once).with(
        anything).and_return { vapp }
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return {}
      mc.should_receive(:upload_catalog_media).with(an_instance_of(String),
        an_instance_of(String), anything).and_return {}
      mc.should_receive(:insert_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:eject_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:set_metadata).with(anything, an_instance_of(String),
        an_instance_of(String)).and_return {}
      mc.should_receive(:get_metadata).with(anything,
        an_instance_of(String)).and_return { UnitTest::AGENT_ENV }
      mc.should_receive(:get_ovdc).at_least(:once).with().and_return {
        UnitTest::Vdc.new("myOvdc") }
      mc.should_receive(:attach_disk).with(
        an_instance_of(UnitTest::Vm::HardDisk), anything).and_return {
        vapp.vms[0].add_hard_disk }
      mc.should_receive(:get_disk).with(an_instance_of(String)).and_return {
        vapp.vms[0].hardware_section.hard_disks.last }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.attach_disk(vapp.name, "test_disk_id")
    end

    it "can detach a disk from a vm" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_vapp).at_least(:once).with(
        anything).and_return { vapp }
      mc.should_receive(:delete_catalog_media).with(
        an_instance_of(String)).and_return {}
      mc.should_receive(:upload_catalog_media).with(an_instance_of(String),
        an_instance_of(String), anything).and_return {}
      mc.should_receive(:insert_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:eject_catalog_media).with(anything,
        an_instance_of(String)).and_return {}
      mc.should_receive(:set_metadata).with(anything, an_instance_of(String),
        an_instance_of(String)).and_return {}
      mc.should_receive(:get_metadata).with(anything,
        an_instance_of(String)).and_return { UnitTest::AGENT_ENV }
      mc.should_receive(:get_ovdc).at_least(:once).with().and_return {
        UnitTest::Vdc.new("myOvdc") }
      mc.should_receive(:detach_disk).with(
        an_instance_of(UnitTest::Vm::HardDisk), anything).and_return {
          vapp.vms[0].del_hard_disk }
      mc.should_receive(:get_disk).with(an_instance_of(String)).and_return {
        vapp.vms[0].hardware_section.hard_disks.last }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.detach_disk(vapp.name, "test_disk_id")
    end

    it "can get the size of a disk" do
      vapp = UnitTest::VApp.new
      mc = mock("client")
      mc.should_receive(:get_disk).with(
        an_instance_of(String)).and_return {
          vapp.vms[0].hardware_section.hard_disks.last }

      cloud = VCloudCloud::Cloud.new(cloud_properties)
      cloud.stub!(:client) { mc }

      cloud.get_disk_size_mb("test_disk_id").should equal(1024.to_i)
    end
  end
end

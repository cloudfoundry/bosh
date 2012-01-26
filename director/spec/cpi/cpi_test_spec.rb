require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../sandbox", __FILE__)
require 'pty'
require 'expect'
require 'rack/test'
require "ruby_vim_sdk"
require "cloud/vsphere/client"
require "cloud/vsphere/resources"

describe Bosh::Director::Clouds::VSphere do
  include Rack::Test::Methods
  include Bosh::Director::IpUtil
  include VimSdk

  AGENT_SRC_PATH  = File.expand_path("../../../../agent", __FILE__)

  def get_ip
    avail_ip = @available_test_ip.first
    @available_test_ip.delete(avail_ip)
    ip_to_netaddr(avail_ip).ip
  end

  def vm_reachable?(ip, timeout = 300)
    `ping -q -c 1 -w #{timeout} #{ip}`
    return $?.exitstatus == 0
  end

  def build_stemcell(pass)
    iso_mnt = ""
    stemcell_tgz = ""
    Dir.chdir(AGENT_SRC_PATH) do
      stemcell_tgz = ""
      PTY.spawn("rake ubuntu:stemcell:build") do |reader, writer, pid|
        reader.expect(/.*password.*:.*/) do
          writer.puts(pass)
        end

        reader.expect(/.*\['mount', '-o', 'loop', '-t', 'iso.*', '.*', '.*/) do
          iso_mnt = reader.gets.split('\'')[0]
        end

        reader.expect(/Generated stemcell:.*/) do
          stemcell_tgz = reader.gets.strip
        end
      end

    end

    # un-mount ubuntu.iso used by vmbuilder.
    PTY.spawn("sudo umount -d #{iso_mnt}") do |reader, writer, pid|
      reader.expect(/.*password.*:.*/)
      writer.puts(pass)
    end
    stemcell_tgz
  end

  def check_vm_tools(vm_cid)
    vm = @vsphere_client.find_by_inventory_path([@datacenter.name, "vm", @datacenter.vm_folder_name, vm_cid])
    return false if vm.nil?
    vm_tools_status = @vsphere_client.get_property(vm, Vim::VirtualMachine, "guest.toolsRunningStatus")
    vm_tools_status == Vim::Vm::GuestInfo::ToolsRunningStatus::GUEST_TOOLS_RUNNING
  end

  # vmbuilder generates bogus stemcells once in a while.
  # deploy a dummy VM to verify the stemcell.
  def stemcell_check
    result = false
    agent_id = UUIDTools::UUID.random_create.to_s
    vm_ip = get_ip
    net_config = {'test' => {'cloud_properties' => @net_conf['cloud_properties'],
      'netmask' => @net_conf['netmask'],
      'gateway' => @net_conf['gateway'],
      'ip'      => vm_ip,
      'dns'     => @net_conf['dns'],
      'default' => ['dns', 'gateway']}}
    begin
      vm_cid = @cloud.create_vm(agent_id, @stemcell_name, @vm_resource, net_config)
      2.times do
        result = check_vm_tools(vm_cid) || vm_reachable?(vm_ip)
        break if result
      end
    ensure
      @cloud.delete_vm(vm_cid) if vm_cid
    end
    result
  end

  before(:all) do
    @test_config = Bosh::Director::Cpi::Sandbox.start
    @net_conf = @test_config['network']

    @available_test_ip = Set.new
    each_ip(@net_conf['range']) do |ip|
      @available_test_ip.add(ip)
    end
    @vm_resource = {"ram" => 1024, "disk"  => 256, "cpu" => 1}

    Thread.new { EM.run{} }
    while !EM.reactor_running?
      sleep 0.1
    end

    Bosh::Director::Config.configure(@test_config)
    cloud_properties = @test_config["cloud"]["properties"]
    @cloud = Bosh::Director::Clouds::VSphere.new(cloud_properties)

    vcenter = cloud_properties["vcenters"][0]
    @vsphere_client = VSphereCloud::Client.new("https://#{vcenter["host"]}/sdk/vimService", cloud_properties)
    @vsphere_client.login(vcenter["user"], vcenter["password"], "en")
    resources = VSphereCloud::Resources.new(@vsphere_client, vcenter, 1.0)
    @datacenter = resources.datacenters.values.first

    valid_stemcell = false
    # try up to 3 times
    3.times do
      stemcell_tgz = @test_config["test"]["stemcell"]
      stemcell_tgz ||= build_stemcell(@test_config["test"]["root_pass"])

      # un-tar stemcell
      stemcell = Dir.mktmpdir("tmp_sc")
      `tar zxf #{stemcell_tgz} -C #{stemcell}`
      if $?.exitstatus != 0
        FileUtils.rm_rf(stemcell)
        raise "Failed to un-tar #{stemcell_tgz}"
      end

      @stemcell_name = @cloud.create_stemcell("#{stemcell}/image", {})
      FileUtils.rm_rf(stemcell)

      # verify stemcell
      valid_stemcell = stemcell_check
      break if valid_stemcell
      @cloud.delete_stemcell(@stemcell_name)
      break if @test_config["test"]["stemcell"]
    end

    unless valid_stemcell
      if @test_config["test"]["stemcell"]
        raise "Invalid stemcell #{@test_config["test"]["stemcell"]}"
      else
        raise "Failed to create a valid stemcell"
      end
    end
  end

  before(:each) do
    Bosh::Director::Config.configure(@test_config)
    @cloud = Bosh::Director::Clouds::VSphere.new(@test_config["cloud"]["properties"])
  end

  after(:all) do
    @cloud = Bosh::Director::Clouds::VSphere.new(@test_config["cloud"]["properties"])
    @cloud.delete_stemcell(@stemcell_name)
    Bosh::Director::Cpi::Sandbox.stop
  end

  it "create/delete a VM" do
    agent_id = UUIDTools::UUID.random_create.to_s
    vm_ip = get_ip
    net_config = {'test' => {'cloud_properties' => @net_conf['cloud_properties'],
                             'netmask' => @net_conf['netmask'],
                             'gateway' => @net_conf['gateway'],
                             'ip'      => vm_ip,
                             'dns'     => @net_conf['dns'],
                             'default' => ['dns', 'gateway']}}
    begin
      vm_cid = @cloud.create_vm(agent_id, @stemcell_name, @vm_resource, net_config)
      vm_reachable?(vm_ip).should == true
    ensure
      @cloud.delete_vm(vm_cid) if vm_cid
    end
  end

  it "reconfigure vm ip address" do
    agent_id = UUIDTools::UUID.random_create.to_s
    vm_ip_a = get_ip
    vm_ip_b = get_ip
    net_config = {'test' => {'cloud_properties' => @net_conf['cloud_properties'],
                             'netmask' => @net_conf['netmask'],
                             'gateway' => @net_conf['gateway'],
                             'ip'      => vm_ip_a,
                             'dns'     => @net_conf['dns'],
                             'default' => ['dns', 'gateway']}}
    begin
      vm_cid = @cloud.create_vm(agent_id, @stemcell_name, @vm_resource, net_config)

      # test network
      vm_reachable?(vm_ip_b, 10).should == false
      vm_reachable?(vm_ip_a).should == true

      pid = Bosh::Director::Cpi::Sandbox.start_nats_tunnel(vm_ip_a)
      agent = Bosh::Director::AgentClient.new(agent_id)
      agent.get_state

      # change the ip
      net_config['test']['ip'] = vm_ip_b
      agent.prepare_network_change(net_config)
      @cloud.configure_networks(vm_cid, net_config)

      # test network
      vm_reachable?(vm_ip_b).should == true
      vm_reachable?(vm_ip_a, 10).should == false
    ensure
      Bosh::Director::Cpi::Sandbox.stop_nats_tunnel(pid) rescue nil
      @cloud.delete_vm(vm_cid) if vm_cid
    end
  end

  it "disk operations create/delete attach/detach and move disk" do
    disk_cid = nil
    2.times do
      agent_id = UUIDTools::UUID.random_create.to_s
      vm_ip = get_ip
      net_config = {'test' => {'cloud_properties' => @net_conf['cloud_properties'],
        'netmask' => @net_conf['netmask'],
        'gateway' => @net_conf['gateway'],
        'ip'      => vm_ip,
        'dns'     => @net_conf['dns'],
        'default' => ['dns', 'gateway']}}
      begin
        vm_cid = @cloud.create_vm(agent_id, @stemcell_name, @vm_resource, net_config)

        vm_reachable?(vm_ip).should == true

        pid = Bosh::Director::Cpi::Sandbox.start_nats_tunnel(vm_ip)
        agent = Bosh::Director::AgentClient.new(agent_id)
        agent.get_state

        disk_cid = @cloud.create_disk(256, vm_cid) unless disk_cid
        @cloud.attach_disk(vm_cid, disk_cid)

        task = agent.mount_disk(disk_cid)
        while task["state"] == "running"
          sleep(1.0)
          task = agent.get_task(task["agent_task_id"])
        end

        task = agent.unmount_disk(disk_cid)
        while task["state"] == "running"
          sleep(1.0)
          task = agent.get_task(task["agent_task_id"])
        end
      ensure
        Bosh::Director::Cpi::Sandbox.stop_nats_tunnel(pid) rescue nil
        @cloud.detach_disk(vm_cid, disk_cid) rescue nil
        @cloud.delete_vm(vm_cid) rescue nil
      end
    end
    @cloud.delete_disk(disk_cid) rescue nil
  end
end

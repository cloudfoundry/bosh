require File.expand_path("../../spec_helper", __FILE__)
require File.expand_path("../sandbox", __FILE__)
require 'pty'
require 'expect'
require 'rack/test'

$expect_verbose = true
describe Bosh::Director::Clouds::VSphere do
  include Rack::Test::Methods
  include Bosh::Director::IpUtil

  AGENT_SRC_PATH  = File.expand_path("../../../../agent", __FILE__)

  def get_ip
    avail_ip = @available_test_ip.first
    @available_test_ip.delete(avail_ip)
    ip_to_netaddr(avail_ip).ip
  end

  def ping_vm(ip, timeout = 300)
    `ping -q -c 1 -w #{timeout} #{ip}`
    return $?.exitstatus == 0
  end

  def build_stemcell(pass)
    sc_path = ""
    iso_mnt = ""
    Dir.chdir(AGENT_SRC_PATH) do
      stemcell_tgz = ""
      PTY.spawn("rake ubuntu:stemcell:build") do |reader, writer, pid|
        reader.expect(/.*password.*:.*/)
        writer.puts(pass)

        reader.expect(/.*\['mount', '-o', 'loop', '-t', 'iso.*', '.*', '.*/)
        iso_mnt = reader.gets.split('\'')[0]

        reader.expect(/Generated stemcell:.*/)
        stemcell_tgz = reader.gets.strip
      end

      sc_path = Dir.mktmpdir("tmp_sc", "/tmp").strip
      `tar zxvf #{stemcell_tgz} -C #{sc_path}`
      FileUtils.rm_rf(stemcell_tgz)
    end

    # un-mount ubuntu.iso used by vmbuilder.
    PTY.spawn("sudo umount -d #{iso_mnt}") do |reader, writer, pid|
      reader.expect(/.*password.*:.*/)
      writer.puts(pass)
    end
    sc_path
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

    stemcell_path = build_stemcell(@test_config["test"]["root_pass"])
    Bosh::Director::Config.configure(@test_config)
    @cloud = Bosh::Director::Clouds::VSphere.new(@test_config["cloud"]["properties"])
    @stemcell_name = @cloud.create_stemcell("#{stemcell_path}/image", {})
    FileUtils.rm_rf(stemcell_path)
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
      ping_vm(vm_ip).should == true
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
      ping_vm(vm_ip_b, 10).should == false
      ping_vm(vm_ip_a).should == true

      pid = Bosh::Director::Cpi::Sandbox.start_nats_tunnel(vm_ip_a)
      agent = Bosh::Director::AgentClient.new(agent_id)
      agent.get_state

      # change the ip
      net_config['test']['ip'] = vm_ip_b
      agent.prepare_network_change(net_config)
      @cloud.configure_networks(vm_cid, net_config, 20)

      # test network
      ping_vm(vm_ip_b).should == true
      ping_vm(vm_ip_a, 10).should == false
    ensure
      Bosh::Director::Cpi::Sandbox.stop_nats_tunnel(pid) rescue nil
      @cloud.delete_vm(vm_cid) if vm_cid
    end
  end

  it "create/attach and detach/delete a disk" do
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

      p = ping_vm(vm_ip)
      p.should == true

      pid = Bosh::Director::Cpi::Sandbox.start_nats_tunnel(vm_ip)
      agent = Bosh::Director::AgentClient.new(agent_id)
      agent.get_state

      disk_cid = @cloud.create_disk(256, vm_cid)
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
      @cloud.delete_disk(disk_cid) rescue nil
      @cloud.delete_vm(vm_cid)
    end
  end
end

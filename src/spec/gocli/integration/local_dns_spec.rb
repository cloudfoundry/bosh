require_relative '../spec_helper'
require 'fileutils'

describe 'local DNS', type: :integration do
  with_reset_sandbox_before_each(dns_enabled: false, local_dns: {'enabled' => true, 'include_index' => false})

  let(:cloud_config) { Bosh::Spec::NewDeployments.simple_cloud_config_with_multiple_azs }
  let(:network_name) { 'local-dns' }

  before do
    cloud_config['networks'][0]['name'] = network_name
    cloud_config['compilation']['network'] = network_name
    upload_cloud_config({cloud_config_hash: cloud_config})
    upload_stemcell
    create_and_upload_test_release(force: true)
  end

  let(:ip_regexp) { /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/ }
  let(:instance_group_name) { 'job_to_test_local_dns' }
  let(:canonical_instance_group_name) { 'job-to-test-local-dns' }
  let(:deployment_name) { 'simple.local_dns' }
  let(:canonical_deployment_name) { 'simplelocal-dns' }
  let(:canonical_network_name) { 'local-dns' }

  context 'small 1 instance deployment' do
    it 'sends sync_dns action agent and updates /etc/hosts' do
      initial_deployment(1)
    end
  end

  it 'sends records for vms that have not yet been created' do
    initial_manifest = initial_manifest(2, 1)
    initial_manifest['instance_groups'][0]['jobs'] = ['name' => 'local_dns_records_json']
    deploy_simple_manifest(manifest_hash: initial_manifest)

    instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)

    recordsHash = JSON.parse(instance.read_file('records-at-prestart.json'))
    expect(recordsHash['records'].size).to equal(2)
  end

  context 'upgrade and downgrade increasing concurrency' do
    context 'upgrade deployment from 1 to 10 instances' do
      it 'sends sync_dns action to all agents and updates agent dns config' do
        manifest_deployment = initial_deployment(1, 5)
        manifest_deployment['instance_groups'][0]['instances'] = 10
        deploy_simple_manifest(manifest_hash: manifest_deployment)

        etc_hosts = parse_agent_etc_hosts(9)
        expect(etc_hosts.size).to eq(10), "expected etc_hosts to have 10 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
        expect(etc_hosts).to match_array(generate_instance_dns)


        (0..9).each do |index|
          records_json = parse_agent_records_json(index)
          expect(records_json['records']).to match_array(generate_instance_records)
          expect(records_json['record_keys']).to match_array(['id', 'num_id', 'instance_group', 'group_ids', 'az', 'az_id', 'network', 'network_id', 'deployment', 'ip', 'domain', 'agent_id', 'instance_index'])
          expect(records_json['record_infos']).to match_array(generate_instance_record_infos)
          expect(records_json['version']).to eq(10)
        end
      end
    end

    context 'concurrency tests' do
      let(:manifest_deployment) { initial_deployment(10, 5) }

      it 'deploys and downgrades with max_in_flight' do
        manifest_deployment['instance_groups'][0]['instances'] = 5
        deploy_simple_manifest(manifest_hash: manifest_deployment)
        etc_hosts = parse_agent_etc_hosts(4)
        expect(etc_hosts.size).to eq(5), "expected etc_hosts to have 5 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
        expect(etc_hosts).to match_array(generate_instance_dns)

        manifest_deployment['instance_groups'][0]['instances'] = 6
        deploy_simple_manifest(manifest_hash: manifest_deployment)
        etc_hosts = parse_agent_etc_hosts(5)
        expect(etc_hosts.size).to eq(6), "expected etc_hosts to have 6 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
        expect(etc_hosts).to match_array(generate_instance_dns)
      end
    end
  end

  context 'recreate' do
    context 'recreates VMs and updates all agents /etc/hosts' do
      context 'manual networking' do
        it 'updates /etc/hosts with the new info for an instance hostname' do
          manifest_deployment = initial_deployment(5)

          deploy_simple_manifest(manifest_hash: manifest_deployment, recreate: true)
          etc_hosts = parse_agent_etc_hosts(4)
          expect(etc_hosts.size).to eq(5), "expected etc_hosts to have 5 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
          expect(etc_hosts).to match_array(generate_instance_dns)
        end
      end

      context 'dynamic networking' do
        before do
          cloud_config['networks'][0]['type'] = 'dynamic'
          cloud_config['networks'][0]['subnets'][0]['range'] = ''
          cloud_config['networks'][0]['subnets'][0]['dns'] = []
          cloud_config['networks'][0]['subnets'][0]['static'] = []

          upload_cloud_config({:cloud_config_hash => cloud_config})
        end

        it 'updates /etc/hosts with the new info for an instance hostname' do
          manifest_deployment = initial_deployment(5)
          old_ips = current_sandbox.cpi.all_ips

          deploy_simple_manifest(manifest_hash: manifest_deployment, recreate: true)

          current_sandbox.cpi.all_ips.each do |new_ip|
            expect(old_ips).to_not include(new_ip)
          end

          etc_hosts = parse_agent_etc_hosts(4)
          expect(etc_hosts.size).to eq(5), "expected etc_hosts to have 5 lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
          expect(etc_hosts).to match_array(generate_instance_dns)
        end
      end
    end

    context 'recreates missing VMs with cck' do
      let(:runner) { bosh_runner_in_work_dir(ClientSandbox.test_release_dir) }

      it 'automatically recreates missing VMs when cck --auto is used' do
        manifest_deployment = initial_deployment(5)

        current_sandbox.cpi.vm_cids.each do |vm_cid|
          current_sandbox.cpi.delete_vm(vm_cid)
        end

        cloudcheck_response = bosh_run_cck_with_auto
        expect(cloudcheck_response).to match(regexp('missing.'))
        expect(cloudcheck_response).to match(regexp('Applying problem resolutions'))
        expect(cloudcheck_response).to match(regexp('Succeeded'))
        expect(cloudcheck_response).to_not match(regexp('0 problems'))
        expect(cloudcheck_response).to_not match(regexp('1. Skip for now
  2. Reboot VM
  3. Recreate VM using last known apply spec
  4. Delete VM
  5. Delete VM reference (DANGEROUS!)'))

        expect(runner.run('cloud-check --report', deployment_name: deployment_name)).to match(regexp('0 problems'))

        etc_hosts = parse_agent_etc_hosts(4)
        expect(etc_hosts).to match_array(generate_instance_dns)
      end
    end
  end

  context 'ordering of tombstone deletion' do
    let(:manifest_deployment) { initial_deployment(2, 1) }

    it 'deploys and downgrades with max_in_flight' do
      manifest_deployment['instance_groups'][0]['instances'] = 1
      deploy_simple_manifest(manifest_hash: manifest_deployment)

      output = bosh_runner.run('task --debug 5')
      puts output

      logpos = /Deleting local dns records for /.match(output).begin(0)
      expect(logpos).to be > 0

      deletepos = /DELETE FROM ["`]local_dns_records["`] WHERE ["`]id["`] = 2/.match(output).begin(0)
      expect(deletepos).to be > logpos

      insertpos = /INSERT INTO ["`]local_dns_records["`] /.match(output).begin(0)
      expect(insertpos).to be > deletepos
    end
  end

  context 'spec.address should respect use_dns_addresses director and deployment level flag (manual networks only)' do
    it 'uses an IP address by default (use_dns_addresses director flag is false by default)' do
      dep_manifest = initial_manifest(1, 1)
      deploy_simple_manifest(manifest_hash: dep_manifest, deployment_name: deployment_name)

      instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
      template = instance.read_job_template('foobar', 'bin/foobar_ctl')
      expect(template).to include('spec.address=192.168.1.2')
    end

    context 'when flag at deployment level is true' do
      let(:features_hash) {{ 'use_dns_addresses' => true, 'use_short_dns_addresses' => use_short_dns_addresses }}
      let(:use_short_dns_addresses) { false }

      before do
        dep_manifest = initial_manifest(1, 1)
        dep_manifest['features'] = features_hash
        deploy_simple_manifest(manifest_hash: dep_manifest, deployment_name: deployment_name)
      end

      it 'uses DNS address' do
        instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
        template = instance.read_job_template('foobar', 'bin/foobar_ctl')
        expect(template).to include("spec.address=#{instance.id}.job-to-test-local-dns.local-dns.simplelocal-dns.bosh")
      end

      context 'when instance is recreated' do
        before do
          bosh_runner.run('recreate job_to_test_local_dns/0', deployment_name: deployment_name)
        end

        it 'renders with the same value' do
          instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          template = instance.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include("spec.address=#{instance.id}.job-to-test-local-dns.local-dns.simplelocal-dns.bosh")
        end
      end

      context 'when resurrected', hm: true do
        with_reset_hm_before_each

        before do
          vm = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          director.kill_vm_and_wait_for_resurrection(vm, deployment_name: deployment_name)
        end

        it 'renders with the same value' do
          instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          template = instance.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include("spec.address=#{instance.id}.job-to-test-local-dns.local-dns.simplelocal-dns.bosh")
        end
      end

      context 'when deployment also specifies use_short_dns_addresses' do
        let(:use_short_dns_addresses) { true }

        it 'uses DNS address' do
          instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          template = instance.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to match(/spec.address=q-m\dn\ds0\.q-g\d\.bosh/)
        end

        context 'when instance is recreated' do
          before do
            bosh_runner.run('recreate job_to_test_local_dns/0', deployment_name: deployment_name)
          end

          it 'renders with short addresses still' do
            instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
            template = instance.read_job_template('foobar', 'bin/foobar_ctl')
            expect(template).to match(/spec.address=q-m\dn\ds0\.q-g\d\.bosh/)
          end
        end

        context 'when resurrected', hm: true do
          with_reset_hm_before_each

          before do
            vm = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
            director.kill_vm_and_wait_for_resurrection(vm, deployment_name: deployment_name)
          end

          it 'renders with short addresses still' do
            instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
            template = instance.read_job_template('foobar', 'bin/foobar_ctl')
            expect(template).to match(/spec.address=q-m\dn\ds0\.q-g\d\.bosh/)
          end
        end
      end
    end

    context 'when flag at deployment level is false' do
      it 'uses an IP address by default' do
        dep_manifest = initial_manifest(1, 1)
        dep_manifest['features'] = {'use_dns_addresses' => false}
        deploy_simple_manifest(manifest_hash: dep_manifest, deployment_name: deployment_name)

        instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
        template = instance.read_job_template('foobar', 'bin/foobar_ctl')
        expect(template).to include('spec.address=192.168.1.2')
      end

      context 'when instance is recreated' do
        before do
          dep_manifest = initial_manifest(1, 1)
          dep_manifest['features'] = {'use_dns_addresses' => false}
          deploy_simple_manifest(manifest_hash: dep_manifest, deployment_name: deployment_name)

          bosh_runner.run('recreate job_to_test_local_dns/0', deployment_name: deployment_name)
        end

        it 'renders with the same value' do
          instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          template = instance.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('spec.address=192.168.1.2')
        end
      end

      context 'when resurrected', hm: true do
        with_reset_hm_before_each

        before do
          dep_manifest = initial_manifest(1, 1)
          dep_manifest['features'] = {'use_dns_addresses' => false}
          deploy_simple_manifest(manifest_hash: dep_manifest, deployment_name: deployment_name)

          vm = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          director.kill_vm_and_wait_for_resurrection(vm, deployment_name: deployment_name)
        end

        it 'renders with the same value' do
          instance = director.instance('job_to_test_local_dns', '0', deployment_name: deployment_name)
          template = instance.read_job_template('foobar', 'bin/foobar_ctl')
          expect(template).to include('spec.address=192.168.1.2')
        end
      end
    end
  end

  def initial_manifest(number_of_instances, max_in_flight)
    manifest_deployment = Bosh::Spec::NewDeployments.test_release_manifest_with_stemcell
    manifest_deployment.merge!(
      {
        'update' => {
          'canaries' => 2,
          'canary_watch_time' => 4000,
          'max_in_flight' => max_in_flight,
          'update_watch_time' => 20
        },

        'instance_groups' => [
          Bosh::Spec::NewDeployments.simple_instance_group(
            name: instance_group_name,
            instances: number_of_instances,
            azs: ['z1', 'z2']
          )
        ]
      })
    manifest_deployment['name'] = deployment_name
    manifest_deployment['instance_groups'][0]['networks'][0]['name'] = network_name
    manifest_deployment
  end

  def initial_deployment(number_of_instances, max_in_flight=1)
    manifest_deployment = initial_manifest(number_of_instances, max_in_flight)
    deploy_simple_manifest(manifest_hash: manifest_deployment)

    etc_hosts = parse_agent_etc_hosts(number_of_instances - 1)
    expect(etc_hosts.size).to eq(number_of_instances), "expected etc_hosts to have #{number_of_instances} lines, got contents #{etc_hosts} with size #{etc_hosts.size}"
    manifest_deployment
  end

  def parse_agent_etc_hosts(instance_index)
    instance = director.instance('job_to_test_local_dns', instance_index.to_s, deployment_name: deployment_name)

    instance.read_etc_hosts.lines.map do |line|
      words = line.strip.split(' ')
      {'hostname' => words[1], 'ip' => words[0]}
    end
  end

  def parse_agent_records_json(instance_index)
    instance = director.instance('job_to_test_local_dns', instance_index.to_s, deployment_name: deployment_name)
    instance.dns_records
  end

  def generate_instance_dns
    director.instances(deployment_name: deployment_name).map do |instance|
      host_name = [
        instance.id,
        canonical_instance_group_name,
        canonical_network_name,
        canonical_deployment_name,
        'bosh'
      ].join('.')
      {
        'hostname' => host_name,
        'ip' => instance.ips[0],
      }
    end
  end

  def generate_instance_records
    director.instances(deployment_name: deployment_name).map do |instance|
      [instance.ips[0], "#{instance.id}.#{canonical_instance_group_name}.#{canonical_network_name}.#{canonical_deployment_name}.bosh"]
    end
  end

  def generate_instance_record_infos
    director.instances(deployment_name: deployment_name).map do |instance|
      if instance.availability_zone.empty?
        az = nil
        az_index = nil
      else
        az = instance.availability_zone
        az_index = Regexp.new(/\d+/)
      end
      [
        instance.id,
        Regexp.new(/\d/),
        Bosh::Director::Canonicalizer.canonicalize(instance.job_name),
        ['1'],
        az,
        az_index,
        Bosh::Director::Canonicalizer.canonicalize('local_dns'),
        Regexp.new(/\d/),
        Bosh::Director::Canonicalizer.canonicalize('simple.local_dns'),
        instance.ips[0],
        'bosh',
        instance.agent_id,
        instance.index.to_i
      ]
    end
  end

  def check_ip(ip, ips)
    case ips
      when String
        return true if ip == ips
      when Array
        return ips.include?(ip)
      else
        return false
    end
  end

  def bosh_run_cck_with_auto
    output = bosh_runner.run("cloud-check --auto", deployment_name: deployment_name)
    if $?.exitstatus != 0
      fail("Cloud check failed, output: #{output}")
    end
    output
  end
end

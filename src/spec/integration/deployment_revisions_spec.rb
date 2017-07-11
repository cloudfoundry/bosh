require 'spec_helper'

describe 'deployment revisions', type: :integration do
  with_reset_sandbox_before_all

  before(:all) do
    manifest_hash = Bosh::Spec::Deployments.simple_manifest
    manifest_hash['jobs'][0]['persistent_disk_pool'] = 'disk_a'
    manifest_hash['jobs'][0]['instances'] = 1
    cloud_config = Bosh::Spec::Deployments.simple_cloud_config
    disk_pool = Bosh::Spec::Deployments.disk_pool
    cloud_config['disk_pools'] = [disk_pool]
    cloud_config['compilation']['reuse_compilation_vms'] = true

    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config)

    cloud_config['compilation']['reuse_compilation_vms'] = false
    upload_cloud_config(cloud_config_hash: cloud_config)

    manifest_hash['jobs'][0]['instances'] = 2
    deploy_simple_manifest(manifest_hash: manifest_hash)

    manifest_hash['jobs'][0]['instances'] = 3
    deploy_simple_manifest(manifest_hash: manifest_hash)

    update_release
    manifest_hash['releases'][0]['version'] = 'latest'
    deploy_simple_manifest(manifest_hash: manifest_hash)
  end

  describe '/deployments/:deployment/diff_revisions' do
    it "returns a diff between 2 revisions" do
      Net::HTTP.start('localhost', 61004, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        request = Net::HTTP::Get.new(URI("https://localhost:61004/deployments/simple/diff_revisions?revision1=1&revision2=2"))
        request.basic_auth('test', 'test')
        response = http.request request
        expect(response.code).to eq('200')

        expect(response.body).to eq('{'\
          '"manifest":['\
            '['\
              '"compilation:",'\
              'null'\
            '],'\
            '['\
              '"  reuse_compilation_vms: true",'\
              '"removed"'\
            '],'\
            '['\
              '"  reuse_compilation_vms: false",'\
              '"added"'\
            '],'\
            '['\
              '"",'\
              'null'\
            '],'\
            '['\
              '"jobs:",'\
              'null'\
            '],'\
            '['\
              '"- name: foobar",'\
              'null'\
            '],'\
            '['\
              '"  instances: 1",'\
              '"removed"'\
            '],'\
            '['\
              '"  instances: 2",'\
              '"added"'\
            ']'\
          '],'\
          '"releases":{'\
            '"added":[],'\
            '"removed":[]'\
          '}'\
        '}')
      end
    end
  end

  describe '/deployments/:deployment/history' do
    it "returns a history" do
      Net::HTTP.start('localhost', 61004, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
        request = Net::HTTP::Get.new(URI("https://localhost:61004/deployments/simple/history"))
        request.basic_auth('test', 'test')
        response = http.request request
        expect(response.code).to eq('200')

        expect(scrub_time(response.body)).to eq('['\
          '{'\
            '"deployment_name":"simple",'\
            '"revision_number":4,'\
            '"user":"test",'\
            '"task":"7",'\
            '"started_at":"0000-00-00 00:00:00 -0000",'\
            '"completed_at":"0000-00-00 00:00:00 UTC",'\
            '"error":null'\
          '},'\
          '{'\
            '"deployment_name":"simple",'\
            '"revision_number":3,'\
            '"user":"test",'\
            '"task":"5",'\
            '"started_at":"0000-00-00 00:00:00 -0000",'\
            '"completed_at":"0000-00-00 00:00:00 UTC",'\
            '"error":null'\
          '},'\
          '{'\
            '"deployment_name":"simple",'\
            '"revision_number":2,'\
            '"user":"test",'\
            '"task":"4",'\
            '"started_at":"0000-00-00 00:00:00 -0000",'\
            '"completed_at":"0000-00-00 00:00:00 UTC",'\
            '"error":null'\
          '},'\
          '{'\
            '"deployment_name":"simple",'\
            '"revision_number":1,'\
            '"user":"test",'\
            '"task":"3",'\
            '"started_at":"0000-00-00 00:00:00 -0000",'\
            '"completed_at":"0000-00-00 00:00:00 UTC",'\
            '"error":null'\
          '}'\
        ']')
      end
    end
  end
end

require 'spec_helper'

describe 'encoding', type: :integration do
  with_reset_sandbox_before_each

  let(:manifest_hash) do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    manifest_hash['instance_groups'].first['properties']['testme'] = 'v🤹🏿<U+200D>♂️ '
    manifest_hash['instance_groups'].first['properties']['moretest'] = '€ ©2017'
    manifest_hash['instance_groups'].first['properties']['arabic'] = 'كلام فارغ'
    manifest_hash['instance_groups'].first['properties']['japanese'] = '曇り'
    manifest_hash['instance_groups'].first['properties']['cyrillic'] = 'я люблю свою работу'
    manifest_hash['instance_groups'].first['properties']['germanic'] = 'Øl weiß æther ångström'
    manifest_hash['instance_groups'].first['properties']['hellenic'] = 'ελληνικά'
    manifest_hash
  end

  it 'supports non-ascii multibyte chars in manifests' do
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
  end

  describe 'when changes to manifests are made' do
    let(:cloud_config_hash) { Bosh::Spec::NewDeployments.simple_cloud_config }

    let(:runtime_config_hash) do
      runtime_config_hash = Bosh::Spec::Deployments.runtime_config_with_addon
      runtime_config_hash['addons'].first['properties']['curren¢y'] = '$ € £ ¥ ₩'
      runtime_config_hash
    end

    let(:cpi_config_yml) do
      cpi_hash = Bosh::Spec::NewDeployments.single_cpi_config('cpi', 'japanese' => '曇り')
      yaml_file('cpi.yml', cpi_hash)
    end

    it 'supports UTF-8 in deployment configuration changes, cloud configuration changes and runtime config changes' do
      deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: cloud_config_hash)

      cloud_config_hash['vm_types'][0]['properties'] = { 'проп1' => 'вал1' }
      upload_cloud_config(cloud_config_hash: cloud_config_hash)
      expect(bosh_runner.run('cloud-config')).to match(/проп1: вал1/)

      upload_runtime_config(runtime_config_hash: runtime_config_hash)
      output = bosh_runner.run('config --name=default --type=runtime')
      expect(output).to include('curren¢y: $ € £ ¥ ₩')

      upload_cpi_yml_output = bosh_runner.run("update-config --name=cpi --type=cpi #{cpi_config_yml.path}")
      expect(upload_cpi_yml_output).to include('Succeeded')

      download_cpi_output = bosh_runner.run('config --name=cpi --type=cpi', tty: false)
      expect(download_cpi_output).to include('cpi', 'japanese: 曇り')

      bosh_runner.run("upload-release #{spec_asset('dummy2-release.tgz')}")

      manifest_hash['update']['canary_watch_time'] = 0
      manifest_hash['instance_groups'][0]['instances'] = 2

      deploy_output = deploy(manifest_hash: manifest_hash, redact_diff: false)

      expect(deploy_output).to match(/vm_types:/)
      expect(deploy_output).to match(/update:/)
      expect(deploy_output).to match(/jobs:/)
      expect(deploy_output).to match(/addons:/)
      expect(deploy_output).to match(/dummy2/)
    end
  end
end

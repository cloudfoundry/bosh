require 'spec_helper'

describe 'encoding', type: :integration do
  with_reset_sandbox_before_each

  it 'supports non-ascii multibyte chars in manifests' do
    manifest_hash = Bosh::Spec::NewDeployments.simple_manifest_with_instance_groups
    manifest_hash['instance_groups'].first['name'] = 'fake-name1'
    manifest_hash['instance_groups'].first['properties']['testme'] = 'v🤹🏿<U+200D>♂️ '
    manifest_hash['instance_groups'].first['properties']['moretest'] = '€ ©2017'
    manifest_hash['instance_groups'].first['properties']['arabic'] = 'كلام فارغ'
    manifest_hash['instance_groups'].first['properties']['japanese'] = '曇り'
    manifest_hash['instance_groups'].first['properties']['russian'] = 'я люблю свою работу'
    deploy_from_scratch(manifest_hash: manifest_hash, cloud_config_hash: Bosh::Spec::NewDeployments.simple_cloud_config)
  end
end

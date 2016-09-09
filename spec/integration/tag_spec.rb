require 'spec_helper'
require 'fileutils'

describe 'Tag', type: :integration do
  let(:cloud_config) { Bosh::Spec::Deployments.simple_cloud_config }

  before do
    target_and_login
    upload_cloud_config
    upload_stemcell
    create_and_upload_test_release
  end

  let(:deployment_name) { 'simple.tag' }
  let(:canonical_deployment_name) { 'simpletag' }
  let(:tags) {
    { 'tags': [{
      'key': 'tag1',
      'value': 'value1'
      }]
    }
  }

  context 'small instance deployment' do
    it 'check that VM has tags' do
      manifest_deployment = Bosh::Spec::Deployments.test_release_manifest
      manifest_deployment.merge!(tags)
      deploy_simple_manifest(manifest_hash: manifest_deployment)

      check_tags(tags)
    end
  end

  def check_tags(expected_tags)
      vm = director.vm('foobar', 0)
      all_requests_file = vm.read_file(File.join('cpi_inputs', 'all_requests'))
      expected_tags.each do |tag|
        expect(all_requests_file ).to include(tag.key)
        expect(all_requests_file ).to include(tag.value)
     end
  end
end

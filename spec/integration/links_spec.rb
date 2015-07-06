require 'spec_helper'

describe 'Links', type: :integration do
  with_reset_sandbox_before_each

  def upload_links_release
    FileUtils.cp_r(LINKS_RELEASE_TEMPLATE, ClientSandbox.links_release_dir, :preserve => true)
    bosh_runner.run_in_dir('create release --force', ClientSandbox.links_release_dir)
    bosh_runner.run_in_dir('upload release', ClientSandbox.links_release_dir)
  end

  before do
    target_and_login
    upload_links_release
    upload_stemcell
    upload_cloud_config
  end

  context 'when job requires link' do
    let(:link_job_spec) { Bosh::Spec::Deployments.simple_job(name: 'link', templates: [{'name' => 'link', 'links' => links}], instances: 1) }
    let(:link_source_job_spec) { Bosh::Spec::Deployments.simple_job(name: 'source', templates: [{'name' => 'source'}], instances: 1) }

    let(:manifest) do
      manifest = Bosh::Spec::NetworkingManifest.deployment_manifest
      manifest['jobs'] = [link_job_spec, link_source_job_spec]
      manifest
    end

    context 'when link is not provided' do
      let(:links) { {} }

      it 'raises an error' do
        _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
        expect(exit_code).to_not eq(0)
      end
    end

    context 'when link is provided' do
      context 'when link reference source that provides link' do
        let(:links) { {'fake_link' => 'simple.source.source.fake_link'} }

        it 'does not raise an error' do
          _, exit_code = deploy_simple_manifest(manifest_hash: manifest, return_exit_code: true)
          expect(exit_code).to eq(0)
        end
      end

      context 'when link reference source that does not provide link' do
        let(:links) { {'fake_link' => 'X.Y.Z.ZZ'} }

        it 'raises an error' do
          _, exit_code = deploy_simple_manifest(manifest_hash: manifest, failure_expected: true, return_exit_code: true)
          expect(exit_code).to_not eq(0)
        end
      end
    end
  end
end

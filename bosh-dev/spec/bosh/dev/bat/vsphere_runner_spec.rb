require 'spec_helper'
require 'bosh/dev/bat/vsphere_runner'

module Bosh::Dev::Bat
  describe VsphereRunner do
    include FakeFS::SpecHelpers

    let(:bosh_cli_session) { instance_double('Bosh::Dev::BoshCliSession', run_bosh: 'fake_BoshCliSession_output') }
    let(:stemcell_archive) { instance_double('Bosh::Dev::Bat::StemcellArchive', version: '6') }
    let(:bat_helper) do
      instance_double('Bosh::Dev::BatHelper',
                      artifacts_dir: '/VsphereRunner_fake_artifacts_dir',
                      micro_bosh_deployment_dir: '/VsphereRunner_fake_artifacts_dir/fake_micro_bosh_deployment_dir',
                      micro_bosh_deployment_name: 'fake_micro_bosh_deployment_name',
                      bosh_stemcell_path: 'fake_bosh_stemcell_path')
    end

    let(:microbosh_deployment_manifest) { instance_double('Bosh::Dev::VSphere::MicroBoshDeploymentManifest', write: nil) }
    let(:bat_deployment_manifest) { instance_double('Bosh::Dev::VSphere::BatDeploymentManifest', write: nil) }

    before do
      FileUtils.mkdir_p(bat_helper.micro_bosh_deployment_dir)

      Bosh::Dev::BatHelper.stub(:new).with('vsphere').and_return(bat_helper)
      Bosh::Dev::BoshCliSession.stub(new: bosh_cli_session)
      Bosh::Dev::Bat::StemcellArchive.stub(:new).with(bat_helper.bosh_stemcell_path).and_return(stemcell_archive)

      Bosh::Dev::VSphere::MicroBoshDeploymentManifest.stub(new: microbosh_deployment_manifest)
      Bosh::Dev::VSphere::BatDeploymentManifest.stub(new: bat_deployment_manifest)

      ENV.stub(:to_hash).and_return(
        'BOSH_VSPHERE_MICROBOSH_IP' => 'fake_BOSH_VSPHERE_MICROBOSH_IP'
      )
    end

    around do |example|
      original_env = ENV

      begin
        ENV.clear
        example.run
      ensure
        ENV.update(original_env)
      end
    end

    describe '#run_bats' do
      let(:bat_rake_task) { double("Rake::Task['bat']", invoke: nil) }

      before do
        Rake::Task.stub(:[]).with('bat').and_return(bat_rake_task)
      end

      it 'generates a micro manifest' do
        microbosh_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_MICROBOSH_MANIFEST'))
        end

        subject.run_bats

        expect(Dir.entries(bat_helper.micro_bosh_deployment_dir)).to include('FAKE_MICROBOSH_MANIFEST')
      end

      it 'targets the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro deployment fake_micro_bosh_deployment_name')
        subject.run_bats
      end

      it 'deploys the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro deploy fake_bosh_stemcell_path')
        subject.run_bats
      end

      it 'logs in to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('login admin admin')
        subject.run_bats
      end

      it 'uploads the bosh stemcell to the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('upload stemcell fake_bosh_stemcell_path', debug_on_fail: true)
        subject.run_bats
      end

      it 'generates a bat manifest' do
        status_output =
          <<-STATUS
            Director
              Name       microbosh-vsphere-jenkins
              URL        https://192.168.202.6:25555
              Version    1.5.0.pre.857 (release:751e27c3 bosh:751e27c3)
              User       admin
              UUID       b6b9cbe8-66d8-4440-9bd8-bd8d1990d574
              CPI        vsphere
              dns        enabled (domain_name: microbosh)
              compiled_package_cache disabled
              snapshots  disabled
          STATUS
        bosh_cli_session.stub(:run_bosh).with('status').and_return(status_output)

        bat_deployment_manifest.should_receive(:write) do
          FileUtils.touch(File.join(Dir.pwd, 'FAKE_BAT_MANIFEST'))
        end

        Bosh::Dev::VSphere::BatDeploymentManifest.should_receive(:new).
          with('b6b9cbe8-66d8-4440-9bd8-bd8d1990d574', '6').and_return(bat_deployment_manifest)

        subject.run_bats

        expect(Dir.entries(bat_helper.artifacts_dir)).to include('FAKE_BAT_MANIFEST')
      end

      it 'sets the the required environment variables' do
        expect(ENV['BAT_DEPLOYMENT_SPEC']).to be_nil
        expect(ENV['BAT_DIRECTOR']).to be_nil
        expect(ENV['BAT_DNS_HOST']).to be_nil
        expect(ENV['BAT_STEMCELL']).to be_nil
        expect(ENV['BAT_VCAP_PASSWORD']).to be_nil
        expect(ENV['BAT_FAST']).to be_nil

        subject.run_bats

        expect(ENV['BAT_DEPLOYMENT_SPEC']).to eq(File.join(bat_helper.artifacts_dir, 'bat.yml'))
        expect(ENV['BAT_DIRECTOR']).to eq('fake_BOSH_VSPHERE_MICROBOSH_IP')
        expect(ENV['BAT_DNS_HOST']).to eq('fake_BOSH_VSPHERE_MICROBOSH_IP')
        expect(ENV['BAT_STEMCELL']).to eq(bat_helper.bosh_stemcell_path)
        expect(ENV['BAT_VCAP_PASSWORD']).to eq('c1oudc0w')
        expect(ENV['BAT_FAST']).to eq('true')
      end

      it 'invokes the "bat" rake task' do
        bat_rake_task.should_receive(:invoke)
        subject.run_bats
      end

      it 'deletes the bat deployment' do
        bosh_cli_session.should_receive(:run_bosh).with('delete deployment bat', ignore_failures: true)
        subject.run_bats
      end

      it 'deletes the stemcell' do
        bosh_cli_session.should_receive(:run_bosh).with("delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true)
        subject.run_bats
      end

      it 'deletes the micro' do
        bosh_cli_session.should_receive(:run_bosh).with('micro delete', ignore_failures: true)
        subject.run_bats
      end

      context 'when a failure occurs' do
        before do
          bat_rake_task.should_receive(:invoke).and_raise
        end

        it 'deletes the bat deployment' do
          bosh_cli_session.should_receive(:run_bosh).with('delete deployment bat', ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end

        it 'deletes the stemcell' do
          bosh_cli_session.should_receive(:run_bosh).with("delete stemcell bosh-stemcell #{stemcell_archive.version}", ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end

        it 'deletes the micro' do
          bosh_cli_session.should_receive(:run_bosh).with('micro delete', ignore_failures: true)
          expect { subject.run_bats }.to raise_error
        end
      end
    end
  end
end

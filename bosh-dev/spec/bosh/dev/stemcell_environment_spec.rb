require 'spec_helper'
require 'fakefs/spec_helpers'
require 'bosh/dev/stemcell_environment'
require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellEnvironment do
    include FakeFS::SpecHelpers

    let(:stemcell_builder) do
      instance_double('Bosh::Dev::StemcellBuilder',
                      directory: '/mnt/stemcells/aws-basic',
                      work_path: '/mnt/stemcells/aws-basic/work')
    end
    let(:env) { ENV.to_hash }

    subject(:environment) do
      StemcellEnvironment.new(stemcell_builder, env)
    end

    describe '#sanitize' do
      let(:mnt_type) { 'ext4' }

      before do
        subject.stub(:system)
        subject.stub(:`).and_return(mnt_type)
        FileUtils.touch('leftover.tgz')
      end

      it 'removes any tgz files from current working directory' do
        expect {
          subject.sanitize
        }.to change { Dir.glob('*.tgz').size }.to(0)
      end

      it 'unmounts work/work/mnt/tmp/grub/root.img' do
        subject.should_receive(:system).with('sudo umount /mnt/stemcells/aws-basic/work/work/mnt/tmp/grub/root.img 2> /dev/null')
        subject.sanitize
      end

      it 'unmounts work/work/mnt directory' do
        subject.should_receive(:system).with('sudo umount /mnt/stemcells/aws-basic/work/work/mnt 2> /dev/null')
        subject.sanitize
      end

      it 'removes /mnt/stemcells/aws-basic' do
        subject.should_receive(:system).with('sudo rm -rf /mnt/stemcells/aws-basic')
        subject.sanitize
      end

      context 'when the mount type is btrfs' do
        let(:mnt_type) { 'btrfs' }

        it 'does not remove /mnt/stemcells/aws-basic' do
          subject.should_not_receive(:system).with(%r{rm .* /mnt/stemcells/aws-basic})
          subject.sanitize
        end
      end
    end

    describe '#default_options' do
      let(:default_disk_size) { 2048 }

      context 'it is not given an infrastructure' do
        it 'dies' do
          STDERR.should_receive(:puts).with('Please specify target infrastructure (vsphere, aws, openstack)')
          environment.should_receive(:exit).with(1).and_raise(SystemExit)

          expect {
            environment.default_options({})
          }.to raise_error(SystemExit)
        end
      end

      context 'it is not given an unknown infrastructure' do
        it 'dies' do
          expect {
            environment.default_options(infrastructure: 'fake')
          }.to raise_error(RuntimeError, /Unknown infrastructure: fake/)
        end
      end

      shared_examples_for 'setting default stemcells environment values' do
        let(:env) do
          {
            'OVFTOOL' => 'fake_ovf_tool_path',
            'STEMCELL_HYPERVISOR' => 'fake_stemcell_hypervisor',
            'STEMCELL_NAME' => 'fake_stemcell_name',
            'UBUNTU_ISO' => 'fake_ubuntu_iso',
            'UBUNTU_MIRROR' => 'fake_ubuntu_mirror',
            'TW_LOCAL_PASSPHRASE' => 'fake_tripwire_local_passphrase',
            'TW_SITE_PASSPHRASE' => 'fake_tripwire_site_passphrase',
            'RUBY_BIN' => 'fake_ruby_bin',
          }
        end

        it 'sets default values for options based in hash' do
          result = environment.default_options(infrastructure: infrastructure)

          expect(result['system_parameters_infrastructure']).to eq(infrastructure)
          expect(result['stemcell_name']).to eq('fake_stemcell_name')
          expect(result['stemcell_infrastructure']).to eq(infrastructure)
          expect(result['stemcell_hypervisor']).to eq('fake_stemcell_hypervisor')
          expect(result['bosh_protocol_version']).to eq('1')
          expect(result['UBUNTU_ISO']).to eq('fake_ubuntu_iso')
          expect(result['UBUNTU_MIRROR']).to eq('fake_ubuntu_mirror')
          expect(result['TW_LOCAL_PASSPHRASE']).to eq('fake_tripwire_local_passphrase')
          expect(result['TW_SITE_PASSPHRASE']).to eq('fake_tripwire_site_passphrase')
          expect(result['ruby_bin']).to eq('fake_ruby_bin')
          expect(result['bosh_release_src_dir']).to match(%r{/bosh/release/src/bosh})
          expect(result['bosh_agent_src_dir']).to match(%r{/bosh/bosh_agent})
          expect(result['image_create_disk_size']).to eq(default_disk_size)
        end

        context 'when RUBY_BIN is not set' do
          let(:env) do
            {
              'OVFTOOL' => 'fake_ovf_tool_path',
              'STEMCELL_HYPERVISOR' => 'fake_stemcell_hypervisor',
              'STEMCELL_NAME' => 'fake_stemcell_name',
              'UBUNTU_ISO' => 'fake_ubuntu_iso',
              'UBUNTU_MIRROR' => 'fake_ubuntu_mirror',
              'TW_LOCAL_PASSPHRASE' => 'fake_tripwire_local_passphrase',
              'TW_SITE_PASSPHRASE' => 'fake_tripwire_site_passphrase',
            }
          end

          before do
            RbConfig::CONFIG.stub(:[]).with('bindir').and_return('/a/path/to/')
            RbConfig::CONFIG.stub(:[]).with('ruby_install_name').and_return('ruby')
          end

          it 'uses the RbConfig values' do
            result = environment.default_options(infrastructure: infrastructure)
            expect(result['ruby_bin']).to eq('/a/path/to/ruby')
          end
        end

        it 'sets the disk_size to 2048MB unless the user requests otherwise' do
          result = environment.default_options(infrastructure: infrastructure)

          expect(result['image_create_disk_size']).to eq(default_disk_size)
        end

        it 'allows user to override default disk_size' do
          result = environment.default_options(infrastructure: infrastructure, disk_size: 1234)

          expect(result['image_create_disk_size']).to eq(1234)
        end
      end

      context 'it is given an infrastructure' do
        context 'when infrastruture is aws' do
          let(:infrastructure) { 'aws' }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            it 'uses "xen"' do
              result = environment.default_options(infrastructure: infrastructure)
              expect(result['stemcell_hypervisor']).to eq('xen')
            end
          end
        end

        context 'when infrastruture is vsphere' do
          let(:infrastructure) { 'vsphere' }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            let(:env) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'uses "esxi"' do
              result = environment.default_options(infrastructure: infrastructure)
              expect(result['stemcell_hypervisor']).to eq('esxi')
            end
          end

          context 'if you have OVFTOOL set in the environment' do
            let(:env) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'sets image_vsphere_ovf_ovftool_path' do
              result = environment.default_options(infrastructure: 'vsphere')
              expect(result['image_vsphere_ovf_ovftool_path']).to eq('fake_ovf_tool_path')
            end
          end

          context 'if you do not have OVFTOOL set in the environment' do
            it 'errors' do
              expect {
                environment.default_options(infrastructure: 'vsphere')
              }.to raise_error(RuntimeError, /Please set OVFTOOL to the path of `ovftool`./)
            end
          end
        end

        context 'when infrastructure is openstack' do
          let(:infrastructure) { 'openstack' }
          let(:default_disk_size) { 10240 }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            it 'uses "kvm"' do
              result = environment.default_options(infrastructure: infrastructure)
              expect(result['stemcell_hypervisor']).to eq('kvm')
            end
          end

          it 'increases default disk_size from 2048 to 10240' do
            result = environment.default_options(infrastructure: 'openstack')

            expect(result['image_create_disk_size']).to eq(10240)
          end

          it 'still allows user to force a specific disk_size' do
            result = environment.default_options(infrastructure: 'openstack', disk_size: 1234)

            expect(result['image_create_disk_size']).to eq(1234)
          end
        end
      end
    end
  end
end

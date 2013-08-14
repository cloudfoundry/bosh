require 'spec_helper'
require 'bosh/dev/stemcell_builder_options'

module Bosh::Dev
  describe StemcellBuilderOptions do
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

    let(:infrastructure) { 'aws' }
    let(:stemcell_tgz) { 'fake-stemcell-filename.tgz' }
    let(:args) do
      {
        infrastructure: infrastructure,
        stemcell_tgz: stemcell_tgz,
        stemcell_version: '123'
      }
    end
    let(:spec) { 'stemcell-aws' }
    let(:source_root) { File.expand_path('../../../../..', __FILE__) }
    let(:build_from_spec) { instance_double('Bosh::Dev::BuildFromSpec', build: nil) }

    subject(:stemcell_builder_options) { StemcellBuilderOptions.new(args: args, environment: env) }

    describe '#basic' do
      let(:default_disk_size) { 2048 }
      let(:rake_args) { {} }

      context 'it is not given an infrastructure' do
        before do
          args.delete(:infrastructure)
        end

        it 'dies' do
          expect {
            stemcell_builder_options.basic
          }.to raise_error /key not found: :infrastructure/
        end
      end

      context 'it is given an unknown infrastructure' do
        let(:infrastructure) { 'fake' }

        it 'dies' do
          expect {
            stemcell_builder_options.basic
          }.to raise_error /invalid infrastructure: fake/
        end
      end

      context 'when given a stemcell_tgz' do
        it 'sets stemcell_tgz' do
          result = stemcell_builder_options.basic
          expect(result['stemcell_tgz']).to eq 'fake-stemcell-filename.tgz'
        end
      end

      context 'when not given a stemcell_tgz' do
        before do
          args.delete(:stemcell_tgz)
        end

        it 'raises' do
          expect {
            stemcell_builder_options.basic
          }.to raise_error /key not found: :stemcell_tgz/
        end
      end

      context 'when given a stemcell_version' do
        it 'sets stemcell_version' do
          result = stemcell_builder_options.basic
          expect(result['stemcell_version']).to eq '123'
        end
      end

      context 'when not given a stemcell_version' do
        before do
          args.delete(:stemcell_version)
        end

        it 'raises' do
          expect {
            stemcell_builder_options.basic
          }.to raise_error /key not found: :stemcell_version/
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
          result = stemcell_builder_options.basic

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
          expect(result['bosh_release_src_dir']).to eq(File.join(source_root, '/release/src/bosh'))
          expect(result['bosh_agent_src_dir']).to eq(File.join(source_root, 'bosh_agent'))
          expect(result['image_create_disk_size']).to eq(default_disk_size)
        end

        context 'when STEMCELL_NAME is not set' do
          before do
            env.delete('STEMCELL_NAME')
          end

          it "defaults to 'bosh-stemcell'" do
            result = stemcell_builder_options.basic

            expect(result['stemcell_name']).to eq ('bosh-stemcell')
          end
        end

        context 'when RUBY_BIN is not set' do
          before do
            env.delete('RUBY_BIN')
          end

          before do
            RbConfig::CONFIG.stub(:[]).with('bindir').and_return('/a/path/to/')
            RbConfig::CONFIG.stub(:[]).with('ruby_install_name').and_return('ruby')
          end

          it 'uses the RbConfig values' do
            result = stemcell_builder_options.basic
            expect(result['ruby_bin']).to eq('/a/path/to/ruby')
          end
        end

        context 'when disk_size is not passed' do
          it 'defaults to default disk size for infrastructure' do
            result = stemcell_builder_options.basic

            expect(result['image_create_disk_size']).to eq(default_disk_size)
          end
        end

        context 'when disk_size is passed' do
          before do
            args.merge!(disk_size: 1234)
          end

          it 'allows user to override default disk_size' do
            result = stemcell_builder_options.basic

            expect(result['image_create_disk_size']).to eq(1234)
          end
        end
      end

      context 'it is given an infrastructure' do
        context 'when infrastruture is aws' do
          let(:infrastructure) { 'aws' }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            before do
              env.delete('STEMCELL_HYPERVISOR')
            end

            it 'uses "xen"' do
              result = stemcell_builder_options.basic
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
              result = stemcell_builder_options.basic
              expect(result['stemcell_hypervisor']).to eq('esxi')
            end
          end

          context 'if you have OVFTOOL set in the environment' do
            let(:env) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'sets image_vsphere_ovf_ovftool_path' do
              result = stemcell_builder_options.basic
              expect(result['image_vsphere_ovf_ovftool_path']).to eq('fake_ovf_tool_path')
            end
          end
        end

        context 'when infrastructure is openstack' do
          let(:infrastructure) { 'openstack' }
          let(:default_disk_size) { 10240 }

          it_behaves_like 'setting default stemcells environment values'

          context 'when STEMCELL_HYPERVISOR is not set' do
            before do
              env.delete('STEMCELL_HYPERVISOR')
            end

            it 'uses "kvm"' do
              result = stemcell_builder_options.basic
              expect(result['stemcell_hypervisor']).to eq('kvm')
            end
          end
        end
      end
    end

    describe '#micro' do
      context 'when a tarball is provided' do
        before do
          args[:tarball] = 'fake/release.tgz'
          stemcell_builder_options.stub(:basic).and_return({ basic: 'options' })
        end

        it 'returns a valid hash' do
          expect(stemcell_builder_options.micro).to eq({
                                                         basic: 'options',
                                                         stemcell_name: 'micro-bosh-stemcell',
                                                         bosh_micro_enabled: 'yes',
                                                         bosh_micro_package_compiler_path: File.join(source_root, 'package_compiler'),
                                                         bosh_micro_manifest_yml_path: File.join(source_root, 'release/micro/aws.yml'),
                                                         bosh_micro_release_tgz_path: 'fake/release.tgz'
                                                       })
        end
      end

      context 'when a tarball is not provided' do
        it 'dies' do
          expect {
            stemcell_builder_options.micro
          }.to raise_error(/key not found: :tarball/)
        end
      end
    end
  end
end

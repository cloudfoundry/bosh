require 'spec_helper'
require 'bosh/stemcell/builder_options'

require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  describe BuilderOptions do
    let(:environment_hash) { {} }

    let(:infrastructure) { Infrastructure.for('aws') }
    let(:operating_system) { OperatingSystem.for('ubuntu') }

    let(:options) do
      {
        tarball: 'fake/release.tgz',
        stemcell_version: '007',
        infrastructure: infrastructure,
        operating_system: operating_system
      }
    end

    let(:expected_source_root) { File.expand_path('../../../../..', __FILE__) }

    let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'FAKE_STEMCELL.tgz') }

    subject(:stemcell_builder_options) { BuilderOptions.new(options) }

    before do
      ENV.stub(to_hash: environment_hash)

      ArchiveFilename.stub(:new).
        with('007', infrastructure, operating_system, 'bosh-stemcell', false).and_return(archive_filename)
    end

    describe '#initialize' do
      context 'when :tarball is not set' do
        before { options.delete(:tarball) }

        it 'dies' do
          expect { stemcell_builder_options }.to raise_error('key not found: :tarball')
        end
      end

      context 'when :stemcell_version is not set' do
        before { options.delete(:stemcell_version) }

        it 'dies' do
          expect { stemcell_builder_options }.to raise_error('key not found: :stemcell_version')
        end
      end

      context 'when :infrastructure is not set' do
        before { options.delete(:infrastructure) }

        it 'dies' do
          expect { stemcell_builder_options }.to raise_error('key not found: :infrastructure')
        end
      end

      context 'when :operating_system is not set' do
        before { options.delete(:operating_system) }

        it 'dies' do
          expect { stemcell_builder_options }.to raise_error('key not found: :operating_system')
        end
      end
    end

    describe '#spec_name' do
      context 'when :infrastructure is aws' do
        it 'returns the spec file basename' do
          expect(stemcell_builder_options.spec_name).to eq('stemcell-aws-xen-ubuntu')
        end
      end

      context 'when :infrastructure is openstack' do
        let(:infrastructure) { Infrastructure.for('openstack') }

        it 'returns the spec file basename' do
          expect(stemcell_builder_options.spec_name).to eq('stemcell-openstack-kvm-ubuntu')
        end
      end

      context 'when :infrastructure is vsphere' do
        let(:infrastructure) { Infrastructure.for('vsphere') }

        it 'returns the spec file basename' do
          expect(stemcell_builder_options.spec_name).to eq('stemcell-vsphere-esxi-ubuntu')
        end

        context 'when :operating_system is centos' do
          let(:operating_system) { OperatingSystem.for('centos') }

          it 'returns the spec file basename' do
            expect(stemcell_builder_options.spec_name).to eq('stemcell-vsphere-esxi-centos')
          end
        end
      end
    end

    describe '#default' do
      let(:default_disk_size) { 2048 }
      let(:rake_args) { {} }

      it 'sets stemcell_tgz' do
        result = stemcell_builder_options.default
        expect(result['stemcell_tgz']).to eq(archive_filename.to_s)
      end

      it 'sets stemcell_version' do
        result = stemcell_builder_options.default
        expect(result['stemcell_version']).to eq('007')
      end

      shared_examples_for 'setting default stemcells environment values' do
        let(:environment_hash) do
          {
            'UBUNTU_ISO' => 'fake_ubuntu_iso',
            'UBUNTU_MIRROR' => 'fake_ubuntu_mirror',
            'TW_LOCAL_PASSPHRASE' => 'fake_tripwire_local_passphrase',
            'TW_SITE_PASSPHRASE' => 'fake_tripwire_site_passphrase',
            'RUBY_BIN' => 'fake_ruby_bin',
          }
        end

        it 'sets default values for options based in hash' do
          expected_release_micro_manifest_path =
            File.join(expected_source_root, "release/micro/#{infrastructure.name}.yml")

          result = stemcell_builder_options.default

          expect(result['system_parameters_infrastructure']).to eq(infrastructure.name)
          expect(result['stemcell_name']).to eq ('bosh-stemcell')
          expect(result['stemcell_infrastructure']).to eq(infrastructure.name)
          expect(result['stemcell_hypervisor']).to eq(infrastructure.hypervisor)
          expect(result['bosh_protocol_version']).to eq('1')
          expect(result['UBUNTU_ISO']).to eq('fake_ubuntu_iso')
          expect(result['UBUNTU_MIRROR']).to eq('fake_ubuntu_mirror')
          expect(result['TW_LOCAL_PASSPHRASE']).to eq('fake_tripwire_local_passphrase')
          expect(result['TW_SITE_PASSPHRASE']).to eq('fake_tripwire_site_passphrase')
          expect(result['ruby_bin']).to eq('fake_ruby_bin')
          expect(result['bosh_release_src_dir']).to eq(File.join(expected_source_root, '/release/src/bosh'))
          expect(result['bosh_agent_src_dir']).to eq(File.join(expected_source_root, 'bosh_agent'))
          expect(result['image_create_disk_size']).to eq(default_disk_size)
          expect(result['bosh_micro_enabled']).to eq('yes')
          expect(result['bosh_micro_package_compiler_path']).to eq(File.join(expected_source_root, 'package_compiler'))
          expect(result['bosh_micro_manifest_yml_path']).to eq(expected_release_micro_manifest_path)
          expect(result['bosh_micro_release_tgz_path']).to eq('fake/release.tgz')
        end

        context 'when RUBY_BIN is not set' do
          before do
            environment_hash.delete('RUBY_BIN')
          end

          before do
            RbConfig::CONFIG.stub(:[]).with('bindir').and_return('/a/path/to/')
            RbConfig::CONFIG.stub(:[]).with('ruby_install_name').and_return('ruby')
          end

          it 'uses the RbConfig values' do
            result = stemcell_builder_options.default

            expect(result['ruby_bin']).to eq('/a/path/to/ruby')
          end
        end

        context 'when disk_size is not passed' do
          it 'defaults to default disk size for infrastructure' do
            result = stemcell_builder_options.default

            expect(result['image_create_disk_size']).to eq(default_disk_size)
          end
        end

        context 'when disk_size is passed' do
          before do
            options.merge!(disk_size: 1234)
          end

          it 'allows user to override default disk_size' do
            result = stemcell_builder_options.default

            expect(result['image_create_disk_size']).to eq(1234)
          end
        end
      end

      describe 'infrastructure variation' do
        context 'when infrastruture is aws' do
          let(:infrastructure) { Infrastructure.for('aws') }

          it_behaves_like 'setting default stemcells environment values'

          it 'has no "image_vsphere_ovf_ovftool_path" key' do
            expect(stemcell_builder_options.default).not_to have_key('image_vsphere_ovf_ovftool_path')
          end
        end

        context 'when infrastruture is vsphere' do
          let(:infrastructure) { Infrastructure.for('vsphere') }

          it_behaves_like 'setting default stemcells environment values'

          it 'has an "image_vsphere_ovf_ovftool_path" key' do
            result = stemcell_builder_options.default

            expect(result['image_vsphere_ovf_ovftool_path']).to be_nil
          end

          context 'if you have OVFTOOL set in the environment' do
            let(:environment_hash) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'sets image_vsphere_ovf_ovftool_path' do
              result = stemcell_builder_options.default

              expect(result['image_vsphere_ovf_ovftool_path']).to eq('fake_ovf_tool_path')
            end
          end
        end

        context 'when infrastructure is openstack' do
          let(:infrastructure) { Infrastructure.for('openstack') }
          let(:default_disk_size) { 10240 }

          it_behaves_like 'setting default stemcells environment values'

          it 'has no "image_vsphere_ovf_ovftool_path" key' do
            expect(stemcell_builder_options.default).not_to have_key('image_vsphere_ovf_ovftool_path')
          end
        end
      end
    end
  end
end

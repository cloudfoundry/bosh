require 'spec_helper'
require 'bosh/stemcell/builder_options'
require 'bosh/stemcell/infrastructure'
require 'bosh/stemcell/operating_system'

module Bosh::Stemcell
  describe BuilderOptions do
    subject(:stemcell_builder_options) { described_class.new(env, options) }
    let(:env) { {} }
    let(:options) do
      {
        tarball: 'fake/release.tgz',
        stemcell_version: '007',
        infrastructure: infrastructure,
        operating_system: operating_system,
        agent_name: agent_name,
      }
    end

    let(:infrastructure) { Infrastructure.for('aws') }
    let(:operating_system) { OperatingSystem.for('ubuntu') }
    let(:agent_name) { 'ruby' }
    let(:expected_source_root) { File.expand_path('../../../../..', __FILE__) }
    let(:archive_filename) { instance_double('Bosh::Stemcell::ArchiveFilename', to_s: 'FAKE_STEMCELL.tgz') }

    before do
      ArchiveFilename.stub(:new).
        with('007', infrastructure, operating_system, 'bosh-stemcell', false, agent_name).and_return(archive_filename)
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

    describe '#default' do
      let(:default_disk_size) { 2048 }
      let(:rake_args) { {} }

      it 'sets stemcell_tgz' do
        result = stemcell_builder_options.default
        expect(result['stemcell_tgz']).to eq(archive_filename.to_s)
      end

      it 'sets stemcell_image_name' do
        result = stemcell_builder_options.default
        expected_image_name = "#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}.raw"
        expect(result['stemcell_image_name']).to eq(expected_image_name)
      end

      it 'sets stemcell_version' do
        result = stemcell_builder_options.default
        expect(result['stemcell_version']).to eq('007')
      end

      # rubocop:disable MethodLength
      def self.it_sets_correct_environment_variables
        describe 'setting enviroment variables' do
          let(:env) do
            {
              'UBUNTU_ISO' => 'fake_ubuntu_iso',
              'UBUNTU_MIRROR' => 'fake_ubuntu_mirror',
              'RUBY_BIN' => 'fake_ruby_bin',
            }
          end

          it 'sets default values for options based in hash' do
            expected_release_micro_manifest_path =
              File.join(expected_source_root, "release/micro/#{infrastructure.name}.yml")

            result = stemcell_builder_options.default

            expect(result['stemcell_name']).to eq(
              "bosh-#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}")
            expect(result['stemcell_operating_system']).to eq(operating_system.name)
            expect(result['stemcell_infrastructure']).to eq(infrastructure.name)
            expect(result['stemcell_hypervisor']).to eq(infrastructure.hypervisor)
            expect(result['bosh_protocol_version']).to eq('1')
            expect(result['UBUNTU_ISO']).to eq('fake_ubuntu_iso')
            expect(result['UBUNTU_MIRROR']).to eq('fake_ubuntu_mirror')
            expect(result['ruby_bin']).to eq('fake_ruby_bin')
            expect(result['bosh_release_src_dir']).to eq(File.join(expected_source_root, '/release/src/bosh'))
            expect(result['bosh_agent_src_dir']).to eq(File.join(expected_source_root, 'bosh_agent'))
            expect(result['go_agent_src_dir']).to eq(File.join(expected_source_root, 'go_agent'))
            expect(result['image_create_disk_size']).to eq(default_disk_size)
            expect(result['bosh_micro_enabled']).to eq('yes')
            expect(result['bosh_micro_package_compiler_path']).to eq(
              File.join(expected_source_root, 'bosh-release'))
            expect(result['bosh_micro_manifest_yml_path']).to eq(expected_release_micro_manifest_path)
            expect(result['bosh_micro_release_tgz_path']).to eq('fake/release.tgz')
          end

          context 'when RUBY_BIN is not set' do
            before { env.delete('RUBY_BIN') }

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
            before { options.merge!(disk_size: 1234) }

            it 'allows user to override default disk_size' do
              result = stemcell_builder_options.default

              expect(result['image_create_disk_size']).to eq(1234)
            end
          end

          context 'when go agent is used' do
            let(:agent_name) { 'go' }

            it 'changes the stemcell_name' do
              result = stemcell_builder_options.default

              expect(result['stemcell_name']).to eq(
                "bosh-#{infrastructure.name}-#{infrastructure.hypervisor}-#{operating_system.name}-go_agent")
            end
          end
        end
      end
      # rubocop:enable MethodLength

      describe 'infrastructure variation' do
        context 'when infrastruture is aws' do
          let(:infrastructure) { Infrastructure.for('aws') }

          it_sets_correct_environment_variables

          it 'has no "image_vsphere_ovf_ovftool_path" key' do
            expect(stemcell_builder_options.default).not_to have_key('image_vsphere_ovf_ovftool_path')
          end
        end

        context 'when infrastruture is vsphere' do
          let(:infrastructure) { Infrastructure.for('vsphere') }
          let(:default_disk_size) { 3072 }

          it_sets_correct_environment_variables

          it 'has an "image_vsphere_ovf_ovftool_path" key' do
            result = stemcell_builder_options.default

            expect(result['image_vsphere_ovf_ovftool_path']).to be_nil
          end

          context 'if you have OVFTOOL set in the environment' do
            let(:env) { { 'OVFTOOL' => 'fake_ovf_tool_path' } }

            it 'sets image_vsphere_ovf_ovftool_path' do
              result = stemcell_builder_options.default

              expect(result['image_vsphere_ovf_ovftool_path']).to eq('fake_ovf_tool_path')
            end
          end
        end

        context 'when infrastructure is openstack' do
          let(:infrastructure) { Infrastructure.for('openstack') }
          let(:default_disk_size) { 10240 }

          it_sets_correct_environment_variables

          it 'has no "image_vsphere_ovf_ovftool_path" key' do
            expect(stemcell_builder_options.default).not_to have_key('image_vsphere_ovf_ovftool_path')
          end
        end
      end
    end
  end
end

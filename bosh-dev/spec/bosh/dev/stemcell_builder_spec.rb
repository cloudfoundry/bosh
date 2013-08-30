require 'spec_helper'
require 'fakefs/spec_helpers'

require 'bosh/dev/stemcell_builder'

module Bosh::Dev
  describe StemcellBuilder do
    include FakeFS::SpecHelpers

    let(:build_number) { '869' }
    let(:infrastructure_name) { 'vsphere' }
    let(:operating_system_name) { 'ubuntu' }

    let(:build) { instance_double('Bosh::Dev::Build', download_release: 'fake release path', number: build_number) }
    let(:gems_generator) { instance_double('Bosh::Dev::GemsGenerator', build_gems_into_release_dir: nil) }

    let(:stemcell_builder_command) do
      instance_double('Bosh::Dev::BuilderCommand', build: nil, chroot_dir: '/fake/chroot/dir')
    end

    let(:fake_work_path) { '/fake/work/path' }
    let(:stemcell_file_path) { File.join(fake_work_path, 'FAKE-stemcell.tgz') }

    subject(:builder) do
      StemcellBuilder.new(build, infrastructure_name, operating_system_name)
    end

    before do
      Bosh::Stemcell::BuilderCommand.stub(:new).with(
        infrastructure_name: infrastructure_name,
        operating_system_name: operating_system_name,
        release_tarball_path: build.download_release,
        version: build_number,
      ).and_return(stemcell_builder_command)
    end

    its(:stemcell_chroot_dir) { should eq('/fake/chroot/dir') }

    describe '#build_stemcell' do
      before do
        GemsGenerator.stub(:new).and_return(gems_generator)

        stemcell_builder_command.stub(:build) do
          FileUtils.mkdir_p(fake_work_path)
          FileUtils.touch(stemcell_file_path)
          stemcell_file_path
        end
      end

      it 'generates the bosh gems' do
        gems_generator.should_receive(:build_gems_into_release_dir)

        builder.build_stemcell
      end

      it 'creates a basic stemcell and returns its absolute path' do
        expect(builder.build_stemcell).to eq('/fake/work/path/FAKE-stemcell.tgz')
      end

      it 'creates a basic stemcell' do
        expect {
          builder.build_stemcell
        }.to change { File.exist?('/fake/work/path/FAKE-stemcell.tgz') }.to(true)
      end

      describe 'when called multiple times' do
        it 'builds the stemcell once' do
          gems_generator.should_receive(:build_gems_into_release_dir).once
          stemcell_builder_command.should_receive(:build).once do
            FileUtils.mkdir_p(fake_work_path)
            FileUtils.touch(stemcell_file_path)
            stemcell_file_path
          end

          2.times { builder.build_stemcell }
        end

        it 'raises an error if the stemcell files does not exist' do
          gems_generator.should_receive(:build_gems_into_release_dir).once
          stemcell_builder_command.should_receive(:build).once do
            FileUtils.mkdir_p(fake_work_path)
            FileUtils.touch(stemcell_file_path)
            stemcell_file_path
          end

          builder.build_stemcell
          FileUtils.rm(stemcell_file_path)

          expect {
            builder.build_stemcell
          }.to raise_error("#{stemcell_file_path} does not exist")
        end
      end

      context 'when the stemcell is not created' do
        before do
          stemcell_builder_command.stub(build: stemcell_file_path)
        end

        it 'fails early and loud' do
          expect {
            builder.build_stemcell
          }.to raise_error("#{stemcell_file_path} does not exist")
        end
      end
    end
  end
end

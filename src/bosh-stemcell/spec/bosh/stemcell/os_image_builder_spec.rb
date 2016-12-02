require 'spec_helper'
require 'bosh/stemcell/archive_handler'
require 'bosh/stemcell/build_environment'
require 'bosh/stemcell/stage_collection'
require 'bosh/stemcell/stage_runner'
require 'bosh/stemcell/os_image_builder'

describe Bosh::Stemcell::OsImageBuilder do
  subject(:builder) do
    described_class.new(
      environment: environment,
      collection: collection,
      runner: runner,
      archive_handler: archive_handler,
    )
  end

  let(:environment) { instance_double('Bosh::Stemcell::BuildEnvironment', prepare_build: nil, chroot_dir: '/chroot') }
  let(:collection) { instance_double('Bosh::Stemcell::StageCollection', operating_system_stages: nil) }
  let(:runner) { instance_double('Bosh::Stemcell::StageRunner', configure_and_apply: nil) }
  let(:archive_handler) { instance_double('Bosh::Stemcell::ArchiveHandler', compress: nil) }

  describe '#build' do
    it 'prepares the build environment' do
      expect(environment).to receive(:prepare_build)
      builder.build('/some/os_image_path.tgz')
    end

    it 'runs the operating system stages' do
      allow(collection).to receive(:operating_system_stages).and_return([:some_stage])
      expect(runner).to receive(:configure_and_apply).with([:some_stage], nil)

      builder.build('/some/os_image_path.tgz')
    end

    it 'tars up the chroot dir' do
      expect(archive_handler).to receive(:compress).with('/chroot', '/some/os_image_path.tgz')

      builder.build('/some/os_image_path.tgz')
    end
  end
end

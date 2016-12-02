require 'spec_helper'
require 'bosh/dev/bosh_release'
require 'bosh/dev/release_creator'

module Bosh::Dev
  describe BoshRelease do
    include FakeFS::SpecHelpers

    subject { described_class.new(release_creator) }
    let(:release_creator) { instance_double('Bosh::Dev::ReleaseCreator') }

    describe '#final_tarball_path' do
      it 'return path to created bosh final release' do
        expect(release_creator)
          .to receive(:create_final)
          .with(no_args)
          .and_return('fake-final-tarball-path')
        expect(subject.final_tarball_path).to eq('fake-final-tarball-path')
      end
    end

    describe '#dev_tarball_path' do
      it 'return path to created bosh dev release' do
        expect(release_creator)
          .to receive(:create_dev)
          .with(no_args)
          .and_return('fake-dev-tarball-path')
        expect(subject.dev_tarball_path).to eq('fake-dev-tarball-path')
      end
    end
  end
end

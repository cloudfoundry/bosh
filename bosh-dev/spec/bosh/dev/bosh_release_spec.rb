require 'spec_helper'
require 'bosh/dev/bosh_release'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  describe BoshRelease do
    include FakeFS::SpecHelpers

    subject { described_class.new(release_creator) }
    let(:release_creator) { instance_double('Bosh::Dev::ReleaseCreator') }

    describe '#tarball_path' do
      it 'creates dev and then final release' do
        release_creator.should_receive(:create).with({}).ordered.and_return('fake-dev-tarball-path')
        release_creator.should_receive(:create).with(final: true).ordered.and_return('fake-final-tarball-path')
        subject.tarball_path.should == 'fake-final-tarball-path'
      end
    end
  end

  describe ReleaseCreator do
    include FakeFS::SpecHelpers

    subject { described_class.new(cli_session) }
    let(:cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

    describe '#create' do
      before { FileUtils.mkdir_p('release') }

      let(:options) { {} }

      create_release_output = <<-OUTPUT
        ...
        Release version: 3
        Release manifest: /tmp/project-release/releases/dummy-3.yml
        Release tarball (2.4K): /tmp/project-release/releases/dummy-3.tgz
      OUTPUT

      it 'is inside release directory when creating final release' do
        cli_session.stub(:run_bosh).with(/create release/) do
          @current_dir = Dir.pwd
          create_release_output
        end
        subject.create(options)
        expect(@current_dir).to eq(File.expand_path('../../../../release', __FILE__))
      end

      context 'when final option is set' do
        before { options.merge!(final: true) }

        it 'creates a new final release tarball' do
          cli_session
            .should_receive(:run_bosh)
            .with('create release --force --final --with-tarball')
            .and_return(create_release_output)
          expect(subject.create(options)).to eq('/tmp/project-release/releases/dummy-3.tgz')
        end
      end

      context 'when final option is not set' do
        it 'creates a new dev release tarball' do
          cli_session
            .should_receive(:run_bosh)
            .with('create release --force --with-tarball')
            .and_return(create_release_output)
          expect(subject.create(options)).to eq('/tmp/project-release/releases/dummy-3.tgz')
        end
      end
    end
  end
end

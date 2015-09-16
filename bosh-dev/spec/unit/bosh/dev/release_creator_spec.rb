require 'spec_helper'
require 'bosh/dev/release_creator'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  describe ReleaseCreator do
    include FakeFS::SpecHelpers

    subject { described_class.new(cli_session) }
    let(:cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

    describe '#create_final' do
      before { FileUtils.mkdir_p('release') }

      create_release_output = <<-OUTPUT
        ...
        Release version: 3
        Release manifest: /tmp/project-release/releases/dummy-3.yml
        Release tarball (2.4K): /tmp/project-release/releases/dummy-3.tgz
      OUTPUT

      it 'is inside release directory when creating final release' do
        old_current_dir = Dir.pwd
        allow(cli_session).to receive(:run_bosh).with(/create release/) do
          @current_dir = Dir.pwd
          create_release_output
        end
        subject.create_final
        expect(@current_dir).to eq(File.join(old_current_dir, 'release'))
      end

      it 'creates a dev release then creates a new final release tarball' do
        expect(cli_session)
          .to receive(:run_bosh)
          .with('create release --force')
          .ordered

        expect(cli_session)
          .to receive(:run_bosh)
          .with('create release --force --final --with-tarball')
          .ordered
          .and_return(create_release_output)

        expect(subject.create_final).to eq('/tmp/project-release/releases/dummy-3.tgz')
      end
    end

    describe '#create_dev' do
      before { FileUtils.mkdir_p('release') }

      create_release_output = <<-OUTPUT
        ...
        Release version: 3.1
        Release manifest: /tmp/project-release/releases/dummy-3.1-dev.yml
        Release tarball (2.4K): /tmp/project-release/releases/dummy-3.1-dev.tgz
      OUTPUT

      it 'is inside release directory when creating final release' do
        old_current_dir = Dir.pwd
        allow(cli_session).to receive(:run_bosh).with(/create release/) do
          @current_dir = Dir.pwd
          create_release_output
        end
        subject.create_dev
        expect(@current_dir).to eq(File.join(old_current_dir, 'release'))
      end

      it 'creates a dev release then creates a new final release tarball' do
        expect(cli_session)
          .to receive(:run_bosh)
          .with('create release --force --with-tarball')
          .and_return(create_release_output)

        expect(subject.create_dev).to eq('/tmp/project-release/releases/dummy-3.1-dev.tgz')
      end
    end
  end
end

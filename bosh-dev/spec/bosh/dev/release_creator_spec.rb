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
        cli_session.stub(:run_bosh).with(/create release/) do
          @current_dir = Dir.pwd
          create_release_output
        end
        subject.create_final
        expect(@current_dir).to eq(File.expand_path('../../../../release', __FILE__))
      end

      it 'creates a dev release then creates a new final release tarball' do
        cli_session
          .should_receive(:run_bosh)
          .with('create release --force')
          .ordered

        cli_session
          .should_receive(:run_bosh)
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
        cli_session.stub(:run_bosh).with(/create release/) do
          @current_dir = Dir.pwd
          create_release_output
        end
        subject.create_dev
        expect(@current_dir).to eq(File.expand_path('../../../../release', __FILE__))
      end

      it 'creates a dev release then creates a new final release tarball' do
        cli_session
          .should_receive(:run_bosh)
          .with('create release --force --with-tarball')
          .and_return(create_release_output)

        expect(subject.create_dev).to eq('/tmp/project-release/releases/dummy-3.1-dev.tgz')
      end
    end
  end
end

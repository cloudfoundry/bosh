require 'spec_helper'
require 'bosh/dev/bosh_release'
require 'bosh/dev/bosh_cli_session'

module Bosh::Dev
  describe BoshRelease do
    include FakeFS::SpecHelpers

    subject { described_class.new(cli_session) }
    let(:cli_session) { instance_double('Bosh::Dev::BoshCliSession') }

    describe '#tarball_path' do
      before { FileUtils.mkdir_p('release') }

      create_release_output = <<-OUTPUT
        ...
        Release version: 3.1-dev
        Release manifest: /tmp/project-release/dev_releases/dummy-3.1-dev.yml
        Release tarball (2.4K): /tmp/project-release/dev_releases/dummy-3.1-dev.tgz
      OUTPUT

      it 'is inside release directory when creating dev release' do
        cli_session.stub(:run_bosh) do
          @current_dir = Dir.pwd
          create_release_output
        end
        subject.tarball_path
        expect(@current_dir).to eq(File.expand_path('../../../../release', __FILE__))
      end

      it 'creates a new release tarball' do
        cli_session
          .should_receive(:run_bosh)
          .with('create release --force --with-tarball')
          .and_return(create_release_output)
        expect(subject.tarball_path).to eq('/tmp/project-release/dev_releases/dummy-3.1-dev.tgz')
      end
    end
  end
end

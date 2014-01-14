require 'spec_helper'
require 'tmpdir'
require 'cli/base_command'

describe Bosh::Cli::Runner do
  let(:runner) { described_class.new([]) }

  before { runner.stub(:exit) }

  describe 'command that raises cli error' do
    let(:runner) { described_class.new(['cli-error']) }

    class CliErrorCommand < Bosh::Cli::Command::Base
      usage 'cli-error'
      desc 'a command that raises a cli error'
      def error
        raise Bosh::Cli::CliError, 'cli-error'
      end
    end

    it 'exits with 1' do
      expect(runner).to receive(:exit).with(1)
      capture_stderr { runner.run }
    end

    it 'writes error output to stderr' do
      stderr = capture_stderr { runner.run }
      expect(stderr).to include 'cli-error'
    end
  end

  describe 'command that raises an unexpected error' do
    let(:runner) { described_class.new(['unexpected-error']) }

    class UnexpectedErrorCommand < Bosh::Cli::Command::Base
      usage 'unexpected-error'
      desc 'a command that raises an unexpected error'
      def error
        raise StandardError, 'unexpected-error'
      end
    end

    it 'propagates the error' do
      expect {
        capture_stderr { runner.run }
      }.to raise_error(StandardError, /unexpected-error/)
    end
  end

  describe 'unknown command' do
    let(:runner) { described_class.new(['bad_argument']) }

    it 'exits with 1' do
      expect(runner).to receive(:exit).with(1)
      capture_stderr { runner.run }
    end

    it 'writes error output to stderr' do
      stderr = capture_stderr { runner.run }
      expect(stderr).to include 'Unknown command: bad_argument'
    end
  end

  describe 'invalid command option' do
    let(:runner) { described_class.new(['invalid-option', '--invalid-option']) }

    class InvalidOptionCommand < Bosh::Cli::Command::Base
      usage 'invalid-option'
      desc 'a command that will be used with an invalid option'
      def invalid_option; end
    end

    it 'exits with 1' do
      expect(runner).to receive(:exit).with(1)
      capture_stderr { runner.run }
    end

    it 'writes error output to stderr' do
      stderr = capture_stderr { runner.run }
      expect(stderr).to include 'invalid option: --invalid-option'
    end
  end

  describe 'plugins' do
    before do
      @original_directory = Dir.pwd
      @tmp_dir = Dir.mktmpdir
      Dir.chdir(@tmp_dir)
    end

    after do
      Dir.chdir(@original_directory)
      FileUtils.rm_rf(@tmp_dir)
    end

    describe 'loading local plugins' do
      context 'when there are no local plugins' do
        it 'should not require any files' do
          runner.should_not_receive(:require_plugin)
          runner.load_local_plugins
        end
      end

      context 'when there are local plugins' do
        before do
          FileUtils.mkdir_p('lib/bosh/cli/commands')
          @plugin_1 = FileUtils.touch('lib/bosh/cli/commands/fake_plugin_1.rb').first
          @plugin_2 = FileUtils.touch('lib/bosh/cli/commands/fake_plugin_2.rb').first
        end

        after { FileUtils.rm_rf('lib') }

        it 'should require all the plugins' do
          runner.should_receive(:require_plugin).with(@plugin_1).once
          runner.should_receive(:require_plugin).with(@plugin_2).once
          runner.load_local_plugins
        end
      end
    end

    describe 'loading gem plugins' do
      let(:spec_1) { instance_double('Gem::Specification') }
      let(:spec_2) { instance_double('Gem::Specification') }

      before do
        FileUtils.mkdir_p('gems/bosh/cli/commands')
        @unique_plugin_1 = FileUtils.touch('gems/bosh/cli/commands/unique_plugin_1.rb').first
        @unique_plugin_2 = FileUtils.touch('gems/bosh/cli/commands/unique_plugin_2.rb').first
        @common_plugin = FileUtils.touch('gems/bosh/cli/commands/common.rb').first

        Gem::Specification.stub(:latest_specs).with(true).and_return { [spec_1, spec_2] }
        spec_1.stub(:matches_for_glob).with('bosh/cli/commands/*.rb').and_return { [@unique_plugin_1, @common_plugin] }
        spec_2.stub(:matches_for_glob).with('bosh/cli/commands/*.rb').and_return { [@unique_plugin_2, @common_plugin] }
      end

      after { FileUtils.rm_rf('gems') }

      it 'requires all the plugins' do
        runner.should_receive(:require_plugin).with(@unique_plugin_1).once
        runner.should_receive(:require_plugin).with(@unique_plugin_2).once
        runner.should_receive(:require_plugin).with(@common_plugin).once
        runner.load_gem_plugins
      end
    end
  end

  def capture_stderr
    orig_stderr = $stderr
    new_stderr = StringIO.new

    $stderr = new_stderr
    yield
    new_stderr.string
  ensure
    $stderr = orig_stderr
  end
end

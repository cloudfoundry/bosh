# Copyright (c) 2009-2012 VMware, Inc.

require 'spec_helper'
require 'tmpdir'

describe Bosh::Cli::Runner do

  let(:runner) { described_class.new([]) }

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

        after do
          FileUtils.rm_rf('lib')
        end

        it 'should require all the plugins' do
          runner.should_receive(:require_plugin).with(@plugin_1).once
          runner.should_receive(:require_plugin).with(@plugin_2).once
          runner.load_local_plugins
        end
      end
    end

    describe 'loading gem plugins' do
      let(:spec_1) { mock }
      let(:spec_2) { mock }

      before do
        FileUtils.mkdir_p('gems/bosh/cli/commands')
        @unique_plugin_1 = FileUtils.touch('gems/bosh/cli/commands/unique_plugin_1.rb').first
        @unique_plugin_2 = FileUtils.touch('gems/bosh/cli/commands/unique_plugin_2.rb').first
        @common_plugin = FileUtils.touch('gems/bosh/cli/commands/common.rb').first

        Gem::Specification.stub(:latest_specs).with(true).and_return { [spec_1, spec_2] }
        spec_1.stub(:matches_for_glob).with('bosh/cli/commands/*.rb').and_return { [@unique_plugin_1, @common_plugin] }
        spec_2.stub(:matches_for_glob).with('bosh/cli/commands/*.rb').and_return { [@unique_plugin_2, @common_plugin] }
      end

      after do
        FileUtils.rm_rf('gems')
      end

      it 'requires all the plugins' do
        runner.should_receive(:require_plugin).with(@unique_plugin_1).once
        runner.should_receive(:require_plugin).with(@unique_plugin_2).once
        runner.should_receive(:require_plugin).with(@common_plugin).once

        runner.load_gem_plugins
      end

      pending 'raises an error if a plugin fails to load'
      pending "warns the user if a loaded plugin doesn't result in any new CLI commands"
    end

  end

  describe 'error output' do

    let(:runner) { described_class.new(['bad_argument']) }

    it 'writes error output to stderr' do
      runner.stub(:exit)
      orig_stderr = $stderr
      $stderr = StringIO.new
      runner.run
      expect($stderr.string).to include 'Unknown command: bad_argument'
      $stderr = orig_stderr
    end
  end
end

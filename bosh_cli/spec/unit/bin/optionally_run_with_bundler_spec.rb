require_relative '../../../bin/optionally_run_with_bundler'

describe 'Optionally run with bundler' do
  let(:gemfile_path) { File.expand_path('../../../bin/run_bosh_with_bundler.Gemfile', File.dirname(__FILE__)) }
  before do
    allow(OptionallyRunWithBundler).to receive(:kernel_exec_current_command)
  end

  describe 'when BOSH_USE_BUNDLER has been set in the ENV' do
    let(:env) { {'BOSH_USE_BUNDLER' => 'TRUE'} }

    describe 'when the bundler gem configuration has been previously setup' do
      before do
        env['BUNDLE_GEMFILE'] = gemfile_path

        File.open(gemfile_path, 'w') { |file| file.write('') } unless File.exists? gemfile_path
      end

      describe 'when RUBYOPT is empty' do
        it 'runs the command with bundler' do
          OptionallyRunWithBundler.run(env)

          expect(env['BUNDLE_GEMFILE']).to eq(gemfile_path)
          expect(env['RUBYOPT']).to include('-rbundler/setup')
        end
      end

      describe 'when RUBYOPT contains rbundler/setup' do
        before { env['RUBYOPT'] = 'blarg'}

        it 'runs the command with bundler' do
          OptionallyRunWithBundler.run(env)

          expect(env['BUNDLE_GEMFILE']).to eq(gemfile_path)
          expect(env['RUBYOPT']).to include('-rbundler/setup blarg')
        end
      end
    end

    describe 'when the bundler gem configuration has NOT been setup' do
      before do
        env['BUNDLE_GEMFILE'] = ''

        File.delete(gemfile_path) if File.exist?(gemfile_path)
      end

      it 'runs the command with bundler' do
        OptionallyRunWithBundler.run(env)

        expect(File.exist?(gemfile_path)).to be_truthy
        expect(File.read(gemfile_path)).to include("gem 'bosh_cli'")
        expect(env['BUNDLE_GEMFILE']).to eq(gemfile_path)
      end
    end

    after do
      File.delete(gemfile_path) if File.exist?(gemfile_path)
    end
  end

  describe 'when BOSH_USE_BUNDLER has NOT been set in the ENV' do
    let(:env) { {} }

    it 'run the command without bundler' do
      expect(File.exist?(gemfile_path)).to be_falsey
      expect(env['BUNDLE_GEMFILE']).not_to eq(gemfile_path)
      expect(env['RUBYOPT']).to be_nil
    end
  end
end

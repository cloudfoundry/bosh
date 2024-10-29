require 'spec_helper'

describe 'cli: login using the directors built-in user DB', type: :integration do
  context 'when users specified in manifest' do
    with_reset_sandbox_before_each

    context 'interactively' do
      it 'can log in' do
        bosh_runner.run_interactively('log-in', include_credentials: false) do |runner|
          expect(runner).to have_output 'Username'
          runner.send_keys 'test'
          expect(runner).to have_output 'Password'
          runner.send_keys 'test'
          expect(runner).to have_output 'Logged in'
        end
      end
    end

    it 'requires login when talking to director' do
      expect(bosh_runner.run('tasks', include_credentials: false, failure_expected: true, environment_name: '\"\"')).to match(/Expected non-empty Director URL/)
      expect(bosh_runner.run('tasks', include_credentials: false, failure_expected: true)).to match(/Not authorized/)
    end

    it 'cannot log in if password is invalid' do
      expect { bosh_runner.run('log-in', client: 'test', client_secret: 'admin') }
        .to raise_error(RuntimeError, /Invalid credentials/)
    end
  end
end

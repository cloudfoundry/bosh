require 'spec_helper'

describe 'create bosh release', type: :integration do
  it 'creates a bosh dev release successfully' do
    # this test is slow. it's running but there's no output until it finishes
    bosh_source_path = File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', '..')
    Dir.mktmpdir('bosh-release-test') do |test_dir|
      cloned_bosh_dir = File.join(test_dir, 'cloned-bosh')

      _, _, exit_status = Open3.capture3("git clone --depth 1 #{bosh_source_path} #{cloned_bosh_dir}")
      expect(exit_status).to be_success

      Bundler.with_clean_env do
        create_dev_release_cmd = 'bundle exec rake release:create_dev_release --trace'
        stdout, _, exit_status = Open3.capture3(create_dev_release_cmd, chdir: cloned_bosh_dir)
        expect(exit_status).to be_success

        expect(stdout).to include('Release name: bosh')
      end
    end
  end
end

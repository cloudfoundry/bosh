require 'spec_helper'

describe 'create bosh release', type: :integration do
  it 'creates a bosh dev release successfully' do
    bosh_source_path = File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', '..')
    Dir.mktmpdir('bosh-release-test') do |test_dir|
      cloned_bosh_dir = File.join(test_dir, 'cloned-bosh')

      _, _, exit_status = Open3.capture3("git clone --depth 1 #{bosh_source_path} #{cloned_bosh_dir}")
      expect(exit_status).to be_success

      Bundler.with_clean_env do
        create_dev_release_cmd = 'bundle exec rake release:create_dev_release --trace'
        output, exit_status = Open3.capture2e(create_dev_release_cmd, chdir: cloned_bosh_dir)
        expect(exit_status).to(be_success, "'#{create_dev_release_cmd}' exited #{exit_status}:\n#{output}")

        expect(output).to include('Release name: bosh')
      end
    end
  end
end

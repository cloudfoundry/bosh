require 'spec_helper'
require 'securerandom'

describe 'create bosh release', type: :integration do
  it 'creates a bosh dev release successfully' do
    clone_source = File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', '..')
    Dir.mktmpdir('bosh-release-test') do |test_dir|
      clone_target = File.join(test_dir, 'cloned-bosh')
      clone_bosh(clone_source, clone_target)

      Bundler.with_clean_env do
        expect(File).to exist(clone_target)

        command = 'bundle exec rake release:create_dev_release --trace'
        output, exit_status = Open3.capture2e(command, chdir: clone_target)
        expect(exit_status).to(be_success, "'#{command}' exited #{exit_status}:\n#{output}")

        expect(output).to include('Release name: bosh')
      end
    end
  end

  private

  def clone_bosh(source, target)
    output, exit_status = Open3.capture2e(%Q{
      set -e
      tempdir=/tmp/bosh-src.#{SecureRandom.hex(4)}
      mkdir $tempdir
      cd #{source}
      cp -R . $tempdir
      cd $tempdir
      rm -rf $(cat .gitignore | sed 's/^\///g')
      mv $tempdir #{target}
    })

    expect(exit_status).to(be_success, "'clone_bosh' exited #{exit_status}:\n#{output}")
  end
end

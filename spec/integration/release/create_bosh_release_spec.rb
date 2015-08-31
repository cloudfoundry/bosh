require 'spec_helper'

describe 'create bosh release', type: :integration do
  it 'creates a bosh dev release successfully' do
    clone_source = File.join(File.expand_path(File.dirname(__FILE__)), '..', '..', '..')
    Dir.mktmpdir('bosh-release-test') do |test_dir|
      clone_target = File.join(test_dir, 'cloned-bosh')
      clone_bosh(clone_source, clone_target)

      Bundler.with_clean_env do
        create_dev_release_cmd = 'bundle exec rake release:create_dev_release --trace'
        output, exit_status = Open3.capture2e(create_dev_release_cmd, chdir: clone_target)
        expect(exit_status).to(be_success, "'#{create_dev_release_cmd}' exited #{exit_status}:\n#{output}")

        expect(output).to include('Release name: bosh')
      end
    end
  end

  def clone_bosh(source, target)
    stdout, stderr, exit_status = Open3.capture3(%Q{
      cd #{source}
      files=$(git ls-files --exclude-standard -c -o)
      for file in $files ; do
        if [ -f "$file" ] ; then
          dir=$(dirname $file)
          mkdir -p #{target}/$dir && cp -R $file #{target}/$dir
        fi
      done
    })

    expect(exit_status).to be_success
  end
end

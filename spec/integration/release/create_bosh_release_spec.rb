require 'spec_helper'

describe 'create bosh release', type: :integration do
  it 'creates a bosh dev release successfully' do
    bosh_source_path = ENV['PWD']
    test_dir = Dir.mktmpdir("bosh-release-test")
    bosh_folder_name = bosh_source_path.split('/').last
    err = nil
    Bundler.with_clean_env do
      create_dev_release = "bundle exec rake release:create_dev_release --trace"
      _, _, err = Open3.capture3("pushd #{test_dir} && git clone #{bosh_source_path} && cd #{bosh_folder_name} && #{create_dev_release}")
    end

    release_folder = Dir.new("#{test_dir}/#{bosh_folder_name}/release/dev_releases/bosh")

    expect(release_folder.entries.any? {|file| file.match(/.*dev.*.yml/)}).to eq(true)
    expect(err.success?).to eq(true)
  end
end

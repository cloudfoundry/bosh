require 'spec_helper'

describe 'Bosh::Spec::IntegrationTest::CliUsage 2' do
  include IntegrationExampleGroup

  # ~65s (possibly includes sandbox start)
  it 'can upload a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    out = run_bosh("upload stemcell #{stemcell_filename}")

    out.should =~ /Stemcell uploaded and created/

    out = run_bosh('stemcells')
    out.should =~ /stemcells total: 1/i
    out.should =~ /ubuntu-stemcell.+1/
    out.should =~ regexp(expected_id.to_s)

    File.exists?(File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")).should be_true
  end

  # ~40s
  it 'can delete a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    out = run_bosh("upload stemcell #{stemcell_filename}")
    out.should =~ /Stemcell uploaded and created/

    File.exists?(File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")).should be_true
    out = run_bosh('delete stemcell ubuntu-stemcell 1')
    out.should =~ /Deleted stemcell `ubuntu-stemcell\/1'/
    File.exists?(File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")).should be_false
  end

  # <9s
  it 'cannot create a final release without the blobstore secret', no_reset: true do
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      out = run_bosh('create release --final', Dir.pwd, failure_expected: true)
      out.should match(/Can't create final release without blobstore secret/)
    end
  end

  # ~31s
  it 'can upload a release' do
    release_filename = spec_asset('valid_release.tgz')

    run_bosh("target http://localhost:#{current_sandbox.director_port}")
    run_bosh('login admin admin')
    out = run_bosh("upload release #{release_filename}")

    out.should =~ /release uploaded/i

    out = run_bosh('releases')
    out.should =~ /releases total: 1/i
    out.should =~ /appcloud.+0\.1/
  end

  # ~32s
  it 'marks releases that have uncommitted changes' do
    release_1 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.yml')
    commit_hash = ''

    Dir.chdir(TEST_RELEASE_DIR) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      new_file = File.join('src', 'bar', 'bla')
      FileUtils.touch(new_file)
      run_bosh('create release --force', Dir.pwd)
      FileUtils.rm_rf(new_file)
      File.exists?(release_1).should be_true
      release_manifest = Psych.load_file(release_1)
      release_manifest['commit_hash'].should == commit_hash
      release_manifest['uncommitted_changes'].should be_true

      run_bosh("target http://localhost:#{current_sandbox.director_port}")
      run_bosh('login admin admin')
      run_bosh('upload release', Dir.pwd)

    end

    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 0.1-dev  | #{commit_hash}+   |
    +--------------+----------+-------------+
    (+) Uncommitted changes

    Releases total: 1
    OUT
  end

end

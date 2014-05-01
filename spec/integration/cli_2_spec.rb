require 'spec_helper'

describe 'cli: 2', type: :integration do
  with_reset_sandbox_before_each

  # ~65s (possibly includes sandbox start)
  it 'can upload a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    target_and_login
    out = bosh_runner.run("upload stemcell #{stemcell_filename}")
    expect(out).to match /Stemcell uploaded and created/

    out = bosh_runner.run('stemcells')
    expect(out).to match /stemcells total: 1/i
    expect(out).to match /ubuntu-stemcell.+1/
    expect(out).to match regexp(expected_id.to_s)

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
  end

  # ~40s
  it 'can delete a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    # That's the contents of image file:
    expected_id = Digest::SHA1.hexdigest("STEMCELL\n")

    target_and_login
    out = bosh_runner.run("upload stemcell #{stemcell_filename}")
    expect(out).to match /Stemcell uploaded and created/

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
    out = bosh_runner.run('delete stemcell ubuntu-stemcell 1')
    expect(out).to match /Deleted stemcell `ubuntu-stemcell\/1'/
    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).not_to be_exists(stemcell_path)
  end

  # <9s
  it 'cannot create a final release without the blobstore secret', no_reset: true do
    Dir.chdir(TEST_RELEASE_DIR) do
      FileUtils.rm_rf('dev_releases')

      out = bosh_runner.run_in_current_dir('create release --final', failure_expected: true)
      expect(out).to match(/Can't create final release without blobstore secret/)
    end
  end

  # ~31s
  it 'can upload a release' do
    release_filename = spec_asset('valid_release.tgz')

    target_and_login
    out = bosh_runner.run("upload release #{release_filename}")

    expect(out).to match /release uploaded/i

    out = bosh_runner.run('releases')
    expect(out).to match /releases total: 1/i
    expect(out).to match /appcloud.+0\.1/
  end

  it 'fails to upload a release that is already uploaded' do
    release_filename = spec_asset('valid_release.tgz')

    target_and_login
    bosh_runner.run("upload release #{release_filename}")
    out = bosh_runner.run("upload release #{release_filename}", failure_expected: true)

    expect(out).to match 'This release version has already been uploaded'
  end

  context 'when deployed' do
    it 'fails to delete release in use but deletes a different release' do
      target_and_login

      runner = bosh_runner_in_work_dir(TEST_RELEASE_DIR)
      runner.run('create release')
      runner.run('upload release')

      # change something in TEST_RELEASE_DIR
      FileUtils.touch(File.join(TEST_RELEASE_DIR, 'src', 'bar', 'pretend_something_changed'))

      runner.run('create release --force')
      runner.run('upload release')

      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")

      deployment_manifest = yaml_file('simple', Bosh::Spec::Deployments.simple_manifest)
      bosh_runner.run("deployment #{deployment_manifest.path}")

      bosh_runner.run('deploy')

      out = bosh_runner.run('delete release bosh-release', failure_expected: true)
      expect(out).to match /Error 30007: Release `bosh-release' is still in use/

      out = bosh_runner.run('delete release bosh-release 0.2-dev')
      expect(out).to match %r{Deleted `bosh-release/0.2-dev'}
    end
  end

  # ~32s
  it 'marks releases that have uncommitted changes' do
    release_1 = File.join(TEST_RELEASE_DIR, 'dev_releases/bosh-release-0.1-dev.yml')
    commit_hash = ''

    Dir.chdir(TEST_RELEASE_DIR) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      new_file = File.join('src', 'bar', 'bla')
      FileUtils.touch(new_file)
      bosh_runner.run_in_current_dir('create release --force')
      FileUtils.rm_rf(new_file)
      expect(File.exists?(release_1)).to be(true)
      release_manifest = Psych.load_file(release_1)
      expect(release_manifest['commit_hash']).to eq commit_hash
      expect(release_manifest['uncommitted_changes']).to be(true)

      target_and_login
      bosh_runner.run_in_current_dir('upload release')
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

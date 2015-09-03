require 'spec_helper'
require 'bosh/dev/table_parser'

describe 'upload release', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each

  # ~31s
  it 'can upload a release' do
    release_filename = spec_asset('test_release.tgz')

    target_and_login
    out = bosh_runner.run("upload release #{release_filename}")

    expect(out).to match /release uploaded/i

    out = bosh_runner.run('releases')
    expect(out).to match /releases total: 1/i
    expect(out).to match /test_release.+1/
  end

  it 'can upload a release without any package changes when using --rebase option' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      out = bosh_runner.run_in_current_dir('create release --with-tarball')
      release_tarball = parse_release_tarball_path(out)

      target_and_login

      # upload the release for the first time
      out = bosh_runner.run("upload release #{release_tarball}")
      expect(out).to match /release uploaded/i

      # upload the same release with --rebase option
      out = bosh_runner.run("upload release #{release_tarball} --rebase")
      expect(out).to match /release rebased/i

      # bosh should be able to generate the next version of the release
      out = bosh_runner.run('releases')
      expect(out).to match /releases total: 1/i
      expect(out).to match /bosh-release.+0\+dev\.1.*0\+dev\.2/m
    end
  end

  # ~33s
  it 'uploads the latest generated release if no release path given' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      bosh_runner.run_in_current_dir('create release')
      target_and_login
      bosh_runner.run_in_current_dir('upload release')
    end

    out = bosh_runner.run('releases')
    expect(out).to match /bosh-release.+0\+dev\.1/
  end

  # ~41s
  it 'sparsely uploads the release' do
    Dir.chdir(ClientSandbox.test_release_dir) do
      FileUtils.rm_rf('dev_releases')

      out = bosh_runner.run_in_current_dir('create release --with-tarball')
      release_tarball_1 = parse_release_tarball_path(out)
      expect(File).to exist(release_tarball_1)

      target_and_login
      bosh_runner.run("upload release #{release_tarball_1}")

      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)

        out = bosh_runner.run_in_current_dir('create release --force --with-tarball')
        release_tarball_2 = parse_release_tarball_path(out)
        expect(File).to exist(release_tarball_2)
      ensure
        FileUtils.rm_rf(new_file)
      end

      out = bosh_runner.run("upload release #{release_tarball_2}")
      expect(out).to match /Checking if can repack release for faster upload/
      expect(out).to match /foo\s*\(.*\)\s*SKIP/
      expect(out).to match /foobar\s*\(.*\)\s*UPLOAD/
      expect(out).to match /bar\s*\(.*\)\s*UPLOAD/
      expect(out).to match /Release repacked/
      expect(out).to match /Started creating new packages > bar.*Done/
      expect(out).to match /Started processing 7 existing packages > Processing 7 existing packages.*Done/
      expect(out).to match /Started processing 8 existing jobs > Processing 8 existing jobs.*Done/
      expect(out).to match /Release uploaded/

      out = bosh_runner.run('releases')
      expect(out).to match /releases total: 1/i
      expect(out).to match /bosh-release.+0\+dev\.1.*0\+dev\.2/m
    end
  end

  # ~9s
  it 'cannot upload malformed release', no_reset: true do
    target_and_login

    release_filename = spec_asset('release_invalid_checksum.tgz')
    out = bosh_runner.run("upload release #{release_filename}", failure_expected: true)
    expect(out).to match /Release is invalid, please fix, verify and upload again/
  end

  # ~32s
  it 'marks releases that have uncommitted changes' do
    commit_hash = ''

    Dir.chdir(ClientSandbox.test_release_dir) do
      commit_hash = `git show-ref --head --hash=8 2> /dev/null`.split.first

      new_file = File.join('src', 'bar', 'bla')
      begin
        FileUtils.touch(new_file)

        out = bosh_runner.run_in_current_dir('create release --force')
        release_manifest_1 = parse_release_manifest_path(out)
        expect(File).to exist(release_manifest_1)
      ensure
        FileUtils.rm_rf(new_file)
      end
      release_manifest = Psych.load_file(release_manifest_1)
      expect(release_manifest['commit_hash']).to eq commit_hash
      expect(release_manifest['uncommitted_changes']).to be(true)

      target_and_login
      bosh_runner.run_in_current_dir('upload release')
    end

    expect_output('releases', <<-OUT)
    +--------------+----------+-------------+
    | Name         | Versions | Commit Hash |
    +--------------+----------+-------------+
    | bosh-release | 0+dev.1  | #{commit_hash}+   |
    +--------------+----------+-------------+
    (+) Uncommitted changes

    Releases total: 1
    OUT
  end

  describe 'uploading a release that already exists' do
    before { target_and_login }

    context 'when the release is local' do
      let(:local_release_path) { spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz') }
      before { bosh_runner.run("upload release #{local_release_path}") }

      it 'includes no package blobs in the repacked release and uploads it to the director' do
        output = bosh_runner.run("upload release #{local_release_path}")
        expect(output).to_not match(/^pkg_.*UPLOAD$/)
        expect(output).to match(/^pkg_.*SKIP$/)
        expect(output).to include("Director task")
        expect(output).to include("Started processing 5 existing packages")
      end
    end

    context 'when the release is remote' do
      let(:file_server) { Bosh::Spec::LocalFileServer.new(spec_asset(''), file_server_port, logger) }
      let(:file_server_port) { current_sandbox.port_provider.get_port(:releases_repo) }

      before { file_server.start }
      after { file_server.stop }

      let(:release_url) { file_server.http_url("compiled_releases/test_release/releases/test_release/test_release-1.tgz") }

      before { bosh_runner.run("upload release #{release_url}") }

      it 'tells the user and does not exit as a failure' do
        output = bosh_runner.run("upload release #{release_url}")

        expect(output).to_not include("Started creating new packages")
        expect(output).to_not include("Started creating new jobs")
        expect(output).to include("Started processing 5 existing packages")
        expect(output).to include("Release uploaded")
      end

      it 'does not affect the blobstore ids of the source package blobs' do
        inspect1 = bosh_runner.run('inspect release test_release/1')
        bosh_runner.run("upload release #{release_url}")
        inspect2 = bosh_runner.run('inspect release test_release/1')

        expect(inspect1).to eq(inspect2)
      end
    end
  end

  describe 're-uploading a release after it fails in a previous attempt' do
    before { target_and_login }

    it 'should not throw an error, and should backfill missing items while not uploading already uploaded packages' do
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release-1-corrupted.tgz')}")
      clean_release_out = bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")

      expect(clean_release_out).to include('pkg_4_depends_on_3 (9207b8a277403477e50cfae52009b31c840c49d4) SKIP')
      expect(clean_release_out).to include('pkg_5_depends_on_4_and_1 (3cacf579322370734855c20557321dadeee3a7a4) UPLOAD')
      expect(clean_release_out).to include('Started creating new packages > pkg_5_depends_on_4_and_1/3cacf579322370734855c20557321dadeee3a7a4. Done')
      expect(clean_release_out).to include('Started processing 4 existing packages > Processing 4 existing packages. Done')
      expect(clean_release_out).to include('Started creating new jobs > job_using_pkg_5/fb41300edf220b1823da5ab4c243b085f9f249af. Done')
      expect(clean_release_out).to include('Started processing 5 existing jobs > Processing 5 existing jobs. Done')

      bosh_releases_out = bosh_runner.run("releases")
      expect(bosh_releases_out).to include(<<-EOF)
+--------------+----------+-------------+
| Name         | Versions | Commit Hash |
+--------------+----------+-------------+
| test_release | 1        | 50e58513+   |
+--------------+----------+-------------+
(+) Uncommitted changes
      EOF

      inspect_release_out = scrub_blobstore_ids(bosh_runner.run("inspect release test_release/1"))
      expect(inspect_release_out).to include(<<-EOF)
+-----------------------+------------------------------------------+--------------------------------------+------------------------------------------+
| Job                   | Fingerprint                              | Blobstore ID                         | SHA1                                     |
+-----------------------+------------------------------------------+--------------------------------------+------------------------------------------+
| job_using_pkg_1       | 9a5f09364b2cdc18a45172c15dca21922b3ff196 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | a7d51f65cda79d2276dc9cc254e6fec523b07b02 |
| job_using_pkg_1_and_2 | 673c3689362f2adb37baed3d8d4344cf03ff7637 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | c9acbf245d4b4721141b54b26bee20bfa58f4b54 |
| job_using_pkg_2       | 8e9e3b5aebc7f15d661280545e9d1c1c7d19de74 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 79475b0b035fe70f13a777758065210407170ec3 |
| job_using_pkg_3       | 54120dd68fab145433df83262a9ba9f3de527a4b | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | ab4e6077ecf03399f215e6ba16153fd9ebbf1b5f |
| job_using_pkg_4       | 0ebdb544f9c604e9a3512299a02b6f04f6ea6d0c | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 1ff32a12e0c574720dd8e5111834bac67229f5c1 |
| job_using_pkg_5       | fb41300edf220b1823da5ab4c243b085f9f249af | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 37350e20c6f78ab96a1191e5d97981a8d2831665 |
+-----------------------+------------------------------------------+--------------------------------------+------------------------------------------+

+--------------------------+------------------------------------------+--------------+--------------------------------------+------------------------------------------+
| Package                  | Fingerprint                              | Compiled For | Blobstore ID                         | SHA1                                     |
+--------------------------+------------------------------------------+--------------+--------------------------------------+------------------------------------------+
| pkg_1                    | 16b4c8ef1574b3f98303307caad40227c208371f | (source)     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 93fade7dd8950d8a1dd2bf5ec751e478af3150e9 |
| pkg_2                    | f5c1c303c2308404983cf1e7566ddc0a22a22154 | (source)     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | b2751daee5ef20b3e4f3ebc3452943c28f584500 |
| pkg_3_depends_on_2       | 413e3e9177f0037b1882d19fb6b377b5b715be1c | (source)     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 62fff2291aac72f5bd703dba0c5d85d0e23532e0 |
| pkg_4_depends_on_3       | 9207b8a277403477e50cfae52009b31c840c49d4 | (source)     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 603f212d572b0307e4c51807c5e03c47944bb9c3 |
| pkg_5_depends_on_4_and_1 | 3cacf579322370734855c20557321dadeee3a7a4 | (source)     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | ad733ca76ab4747747d8f9f1ddcfa568519a2e00 |
+--------------------------+------------------------------------------+--------------+--------------------------------------+------------------------------------------+
      EOF
    end

    it 'does not allow uploading same release version with different commit hash' do
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release-1-corrupted_with_different_commit.tgz')}")
      expect {
        bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      }.to raise_error(RuntimeError, /Error 30014: release `test_release\/1' has already been uploaded with commit_hash as `50e58513' and uncommitted_changes as `true'/)
    end
  end

  describe 'uploading a release with the same packages as some other release' do
    before { target_and_login }

    it 'omits identical packages from the repacked tarball and creates new copies of the blobstore entries under the new release' do
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/release_with_shared_blobs/release_with_shared_blobs-1.tgz')}")

      expect(output).to_not match(/^pkg_.*UPLOAD$/)
      expect(output).to match(/^pkg_.*SKIP$/)

      test_release_desc = bosh_runner.run("inspect release test_release/1")
      shared_release_desc = bosh_runner.run("inspect release release_with_shared_blobs/1")

      expect(test_release_desc).to_not eq(shared_release_desc)
      expect(scrub_blobstore_ids(test_release_desc)).to eq(scrub_blobstore_ids(shared_release_desc))
    end

    it 'raises an error if the uploaded release version already exists but there are packages with different fingerprints' do
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")

      expect {
        bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1-pkg2-updated.tgz')}")
      }.to raise_error(RuntimeError, /Error 30012: package `pkg_2' had different fingerprint in previously uploaded release `test_release\/1'/)
    end

    it 'raises an error if the uploaded release version already exists but there are jobs with different fingerprints' do
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")

      expect {
        bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1-job1-updated.tgz')}")
      }.to raise_error(RuntimeError, /Error 30013: job `job_using_pkg_1' had different fingerprint in previously uploaded release `test_release\/1'/)
    end

    it "allows sharing of packages across releases when the original packages does not have source" do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/release_with_shared_blobs/release_with_shared_blobs-1.tgz')}")
      expect(output).to include("Started creating new packages > pkg_1/16b4c8ef1574b3f98303307caad40227c208371f. Done")
      expect(output).to include("Started release has been created > release_with_shared_blobs/1. Done")
    end
  end

  describe 'uploading compiled releases' do
    before { target_and_login }

    it 'should raise an error if no stemcell matched the criteria' do
      expect {
        bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-centos-7-stemcell-3001.tgz')}")
      }.to raise_error(RuntimeError, /No stemcells matching OS centos-7 version 3001/)
    end

    it 'should populate compiled packages for one stemcell' do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-centos-7-stemcell-3001.tgz')}")

      expect(output).to include("Started creating new packages > go-lang-1.4.2/7d4bf6e5267a46d414af2b9a62e761c2e5f33a8d.")
      expect(output).to include('Started creating new compiled packages > go-lang-1.4.2/7d4bf6e5267a46d414af2b9a62e761c2e5f33a8d for bosh-aws-xen-hvm-centos-7-go_agent/3001')
      expect(output).to include('Started creating new compiled packages > hello-go/03df8c27c4525622aacc0d7013af30a9f2195393 for bosh-aws-xen-hvm-centos-7-go_agent/3001')
      expect(output).to include("Started creating new jobs > hello-go/0cf937b9a063cf96bd7506fa31699325b40d2d08.")
      expect(output).to include("Release uploaded")
    end

    it 'should populate compiled packages for two matching stemcells' do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-centos-7-stemcell-3001.tgz')}")

      expect(output).to include("Started creating new packages > go-lang-1.4.2/7d4bf6e5267a46d414af2b9a62e761c2e5f33a8d")
      expect(output).to include('Started creating new compiled packages > go-lang-1.4.2/7d4bf6e5267a46d414af2b9a62e761c2e5f33a8d for bosh-aws-xen-centos-7-go_agent/3001')
      expect(output).to include('Started creating new compiled packages > go-lang-1.4.2/7d4bf6e5267a46d414af2b9a62e761c2e5f33a8d for bosh-aws-xen-hvm-centos-7-go_agent/3001')
      expect(output).to include('Started creating new compiled packages > hello-go/03df8c27c4525622aacc0d7013af30a9f2195393 for bosh-aws-xen-centos-7-go_agent/3001')
      expect(output).to include('Started creating new compiled packages > hello-go/03df8c27c4525622aacc0d7013af30a9f2195393 for bosh-aws-xen-hvm-centos-7-go_agent/3001')
      expect(output).to include('Started creating new jobs > hello-go/0cf937b9a063cf96bd7506fa31699325b40d2d08.')
      expect(output).to include("Release uploaded")
    end

    it 'upload a compiled release tarball' do
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")
      expect(output).to include('Started creating new packages > hello-go/b3df8c27c4525622aacc0d7013af30a9f2195393')
      expect(output).to include('Started creating new compiled packages > hello-go/b3df8c27c4525622aacc0d7013af30a9f2195393 for ubuntu-stemcell/1.')
      expect(output).to include('Started creating new jobs > hello-go/0cf937b9a063cf96bd7506fa31699325b40d2d08')
      expect(output).to include('Release uploaded')
    end

    it 'should not do any expensive operations for 2nd upload of a compiled release tarball' do
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")
      expect(output).to match(/^hello-go.*UPLOAD$/)
      expect(output).to match(/Uploading the whole release/)
      expect(output).to match(/Started creating new packages/)
      expect(output).to match(/Started creating new compiled packages/)
      expect(output).to match(/Started creating new jobs/)

      output = bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")
      expect(output).to match(/^hello-go.*SKIP$/)
      expect(output).to match(/Release repacked/)
      expect(output).to_not match(/Uploading the whole release/)
      expect(output).to_not match(/Started creating new packages/)
      expect(output).to_not match(/Started creating new compiled packages/)
      expect(output).to_not match(/Started creating new jobs/)
    end

    it 'show actions in the event log' do
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")

      event_log = bosh_runner.run('task last --event --raw')
      expect(event_log).to include("Creating new jobs")
      expect(event_log).to include("hello-go/0cf937b9a063cf96bd7506fa31699325b40d2d08")
    end

    it 'upload a new version of compiled release tarball when the compiled release is already uploaded' do
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')}")
      bosh_runner.run("upload release #{spec_asset('release-hello-go-50-on-toronto-os-stemcell-1.tgz')}")

      output, exit_code = bosh_runner.run("upload release #{spec_asset('release-hello-go-51-on-toronto-os-stemcell-1.tgz')}")
      expect(output).to include('Started processing 1 existing package > Processing 1 existing package')
      expect(output).to include('Started processing 1 existing job > Processing 1 existing job')
      expect(output).to include('Release uploaded')
    end

    it 'backfills the source code for an already exisiting compiled release' do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      expect(output).to include('Release uploaded')

      output = bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      expect(output).to include('Release uploaded')

      output = bosh_runner.run('inspect release test_release/1')
      expect(output).to_not include('no source')
    end

    it 'backfill sourceof an already exisitng compiled release when there is another release that has exactly same contents' do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")

      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release_with_different_name.tgz')}")
      bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")

      inspect_release_with_other_name_out = bosh_runner.run("inspect release test_release_with_other_name/1")
      inspect_release_out = bosh_runner.run("inspect release test_release/1")

      expect(scrub_blobstore_ids(inspect_release_out)).to include(<<-EOF)
+--------------------------+------------------------------------------+-----------------------------------------+--------------------------------------+------------------------------------------+
| Package                  | Fingerprint                              | Compiled For                            | Blobstore ID                         | SHA1                                     |
+--------------------------+------------------------------------------+-----------------------------------------+--------------------------------------+------------------------------------------+
| pkg_1                    | 16b4c8ef1574b3f98303307caad40227c208371f | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 93fade7dd8950d8a1dd2bf5ec751e478af3150e9 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 735987b52907d970106f38413825773eec7cc577 |
| pkg_2                    | f5c1c303c2308404983cf1e7566ddc0a22a22154 | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | b2751daee5ef20b3e4f3ebc3452943c28f584500 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 5b21895211d8592c129334e3d11bd148033f7b82 |
| pkg_3_depends_on_2       | 413e3e9177f0037b1882d19fb6b377b5b715be1c | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 62fff2291aac72f5bd703dba0c5d85d0e23532e0 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | f5cc94a01d2365bbeea00a4765120a29cdfb3bd7 |
| pkg_4_depends_on_3       | 9207b8a277403477e50cfae52009b31c840c49d4 | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 603f212d572b0307e4c51807c5e03c47944bb9c3 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | f21275861158ad864951faf76da0dce9c1b5f215 |
| pkg_5_depends_on_4_and_1 | 3cacf579322370734855c20557321dadeee3a7a4 | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | ad733ca76ab4747747d8f9f1ddcfa568519a2e00 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 002deec46961440df01c620be491e5b12246c5df |
+--------------------------+------------------------------------------+-----------------------------------------+--------------------------------------+------------------------------------------+
      EOF

      # make sure the the blobstore_ids of the packages in the 2 releases are different
      inspect_release_with_other_name_array = Bosh::Dev::TableParser.new(inspect_release_with_other_name_out.split(/\n\n/)[1]).to_a
      inspect_release_array = Bosh::Dev::TableParser.new(inspect_release_out.split(/\n\n/)[1]).to_a

      inspect_release_with_other_name_array.each { |other_name_package|
        inspect_release_array.each { |test_release_pkg|
          if other_name_package[:package] == test_release_pkg[:package]
            expect(other_name_package[:blobstore_id]).to_not eq(test_release_pkg[:blobstore_id])
          end
        }
      }

    end

    it 'allows uploading a compiled release after its source release has been uploaded' do
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload stemcell #{spec_asset('light-bosh-stemcell-3001-aws-xen-hvm-centos-7-go_agent.tgz')}")
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")

      output = bosh_runner.run("upload release #{spec_asset('compiled_releases/release-test_release-1-on-centos-7-stemcell-3001.tgz')}")
      expect(output).to include('Release uploaded')

      output = scrub_blobstore_ids(bosh_runner.run('inspect release test_release/1'))
      expect(output).to include(<<-EOF)
+-----------------------+------------------------------------------+--------------------------------------+------------------------------------------+
| Job                   | Fingerprint                              | Blobstore ID                         | SHA1                                     |
+-----------------------+------------------------------------------+--------------------------------------+------------------------------------------+
| job_using_pkg_1       | 9a5f09364b2cdc18a45172c15dca21922b3ff196 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | a7d51f65cda79d2276dc9cc254e6fec523b07b02 |
| job_using_pkg_1_and_2 | 673c3689362f2adb37baed3d8d4344cf03ff7637 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | c9acbf245d4b4721141b54b26bee20bfa58f4b54 |
| job_using_pkg_2       | 8e9e3b5aebc7f15d661280545e9d1c1c7d19de74 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 79475b0b035fe70f13a777758065210407170ec3 |
| job_using_pkg_3       | 54120dd68fab145433df83262a9ba9f3de527a4b | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | ab4e6077ecf03399f215e6ba16153fd9ebbf1b5f |
| job_using_pkg_4       | 0ebdb544f9c604e9a3512299a02b6f04f6ea6d0c | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 1ff32a12e0c574720dd8e5111834bac67229f5c1 |
| job_using_pkg_5       | fb41300edf220b1823da5ab4c243b085f9f249af | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 37350e20c6f78ab96a1191e5d97981a8d2831665 |
+-----------------------+------------------------------------------+--------------------------------------+------------------------------------------+

+--------------------------+------------------------------------------+-----------------------------------------+--------------------------------------+------------------------------------------+
| Package                  | Fingerprint                              | Compiled For                            | Blobstore ID                         | SHA1                                     |
+--------------------------+------------------------------------------+-----------------------------------------+--------------------------------------+------------------------------------------+
| pkg_1                    | 16b4c8ef1574b3f98303307caad40227c208371f | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 93fade7dd8950d8a1dd2bf5ec751e478af3150e9 |
|                          |                                          | bosh-aws-xen-centos-7-go_agent/3001     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 735987b52907d970106f38413825773eec7cc577 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 735987b52907d970106f38413825773eec7cc577 |
| pkg_2                    | f5c1c303c2308404983cf1e7566ddc0a22a22154 | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | b2751daee5ef20b3e4f3ebc3452943c28f584500 |
|                          |                                          | bosh-aws-xen-centos-7-go_agent/3001     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 5b21895211d8592c129334e3d11bd148033f7b82 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 5b21895211d8592c129334e3d11bd148033f7b82 |
| pkg_3_depends_on_2       | 413e3e9177f0037b1882d19fb6b377b5b715be1c | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 62fff2291aac72f5bd703dba0c5d85d0e23532e0 |
|                          |                                          | bosh-aws-xen-centos-7-go_agent/3001     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | f5cc94a01d2365bbeea00a4765120a29cdfb3bd7 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | f5cc94a01d2365bbeea00a4765120a29cdfb3bd7 |
| pkg_4_depends_on_3       | 9207b8a277403477e50cfae52009b31c840c49d4 | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 603f212d572b0307e4c51807c5e03c47944bb9c3 |
|                          |                                          | bosh-aws-xen-centos-7-go_agent/3001     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | f21275861158ad864951faf76da0dce9c1b5f215 |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | f21275861158ad864951faf76da0dce9c1b5f215 |
| pkg_5_depends_on_4_and_1 | 3cacf579322370734855c20557321dadeee3a7a4 | (source)                                | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | ad733ca76ab4747747d8f9f1ddcfa568519a2e00 |
|                          |                                          | bosh-aws-xen-centos-7-go_agent/3001     | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 002deec46961440df01c620be491e5b12246c5df |
|                          |                                          | bosh-aws-xen-hvm-centos-7-go_agent/3001 | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | 002deec46961440df01c620be491e5b12246c5df |
+--------------------------+------------------------------------------+-----------------------------------------+--------------------------------------+------------------------------------------+
      EOF
    end

    it 'allows uploading two source releases with different version numbers but identical contents' do
      bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-1.tgz')}")
      output = bosh_runner.run("upload release #{spec_asset('compiled_releases/test_release/releases/test_release/test_release-4-same-packages-as-1.tgz')}")
      expect(output).to include("Release uploaded")
    end
  end
end

require 'securerandom'
require 'spec_helper'

describe 'finalize release', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  SHA1_REGEXP = /^[0-9a-f]{40}$/

  before { setup_test_release_dir }

  describe 'release finalization' do
    context 'when finalizing a release that was built elsewhere' do
      it 'updates the .final_builds index for each job and package' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}")

          job_index = Psych.load_file(File.absolute_path('.final_builds/jobs/dummy/index.yml'))
          expect(job_index).to include('builds')
          expect(job_index['builds']).to include('a2f501d07c3e96689185ee6ebe26c15d54d4849a')
          expect(job_index['builds']['a2f501d07c3e96689185ee6ebe26c15d54d4849a']).to include('version', 'blobstore_id', 'sha1')

          package_index = Psych.load_file(File.absolute_path('.final_builds/packages/dummy_package/index.yml'))
          expect(package_index).to include('builds')
          expect(package_index['builds']).to include('a29b3b1174dc200826055732082bf21c7a765669')
          expect(package_index['builds']['a29b3b1174dc200826055732082bf21c7a765669']).to include('version', 'blobstore_id', 'sha1')
        end
      end

      it 'prints release summary' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          out = bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}")
          expect(format_output(out).index(format_output(<<-OUT))).to_not be_nil
            Release summary
            ---------------

            Packages
            +---------------+---------+-------+
            | Name          | Version | Notes |
            +---------------+---------+-------+
            | bad_package   | 0.1-dev |       |
            | dummy_package | 0.1-dev |       |
            +---------------+---------+-------+

            Jobs
            +------------------------+----------+-------+
            | Name                   | Version  | Notes |
            +------------------------+----------+-------+
            | dummy                  | 0.2-dev  |       |
            | dummy_with_bad_package | 0.1-dev  |       |
            | dummy_with_package     | 0.1-dev  |       |
            | dummy_with_properties  | 0.1-dev  |       |
            | multi-monit-dummy      | 0.13-dev |       |
            +------------------------+----------+-------+

            Release name: dummy
            Release version: 1
          OUT
        end
      end

      it 'updates the releases index' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}")
          job_index = Psych.load_file(File.absolute_path('.final_builds/jobs/dummy/index.yml'))
          expect(job_index).to include('builds')
          expect(job_index['builds']).to include('a2f501d07c3e96689185ee6ebe26c15d54d4849a')
          expect(job_index['builds']['a2f501d07c3e96689185ee6ebe26c15d54d4849a']).to include('version', 'blobstore_id', 'sha1')
        end
      end

      it 'updates the latest release pointer in config/dev.yml' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          out = bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}")
          expect(out).to match('Creating final release dummy/1 from dev release dummy/0.2-dev')
          dev_config = Psych.load_file(File.join('config', 'dev.yml'))
          expect(dev_config['latest_release_filename']).to eq(File.absolute_path(File.join('releases', 'dummy', 'dummy-1.yml')))

          out = bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}")
          expect(out).to match('Creating final release dummy/2 from dev release dummy/0.2-dev')
          dev_config = Psych.load_file(File.join('config', 'dev.yml'))
          expect(dev_config['latest_release_filename']).to eq(File.absolute_path(File.join('releases', 'dummy', 'dummy-2.yml')))
        end
      end

      it 'cannot create a final release without the blobstore configured' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          FileUtils.cp(spec_asset('empty_blobstore_config.yml'), 'config/final.yml')
          out = bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}", failure_expected: true)
          expect(out).to match(/Missing blobstore configuration, please update config\/final\.yml/)
        end
      end

      it 'cannot create a final release without the blobstore secret configured' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          FileUtils.cp(spec_asset('blobstore_config_requiring_credentials.yml'), 'config/final.yml')
          out = bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}", failure_expected: true)
          expect(out).to match(/Missing blobstore secret configuration, please update config\/private\.yml/)
        end
      end

      context 'when no previous releases have been made' do
        it 'finalize release uploads the job & package blobs' do
          Dir.chdir(ClientSandbox.test_release_dir) do
            expect(Dir).to_not exist('releases')
            expect(Dir).to_not exist('dev_releases')
            expect(Dir).to_not exist('.final_builds')
            expect(Dir).to_not exist('.dev_builds')
            expect(Dir).to_not exist(ClientSandbox.blobstore_dir)

            bosh_runner.run_in_current_dir("finalize release #{spec_asset('dummy-release.tgz')}")
            expect(File).to exist('releases/dummy/dummy-1.yml')
            expect(File).to exist('.final_builds/jobs/dummy/index.yml')
            expect(File).to exist('.final_builds/packages/bad_package/index.yml')
            uploaded_blob_count = Dir[File.join(ClientSandbox.blobstore_dir, '**', '*')].length
            expect(uploaded_blob_count).to eq(7)
          end
        end
      end
    end

    context 'when finalizing a release that was built in the current release dir' do
      it 'can finalize the dev release tarball' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          bosh_runner.run_in_current_dir("create release --force --with-tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize release dev_releases/test-release/test-release-0+dev.1.tgz")
          expect(out).to match(/Creating final release test-release\/1 from dev release test-release\/0\+dev\.1/)
        end
      end

      it 'includes the LICENSE file' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          expect(File).to_not exist('NOTICE')
          File.open('LICENSE', 'w') do |f|
            f.write('This is an example license file')
          end
          bosh_runner.run_in_current_dir("create release --force --with-tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize release dev_releases/test-release/test-release-0+dev.1.tgz")

          expected_license_version = '7a59f7973cddfa0301ca34a29d4cc876247dd7de'
          expect(out).to match(/\| license \| #{expected_license_version} \|/)
          expect(blobstore_tarball_listing(expected_license_version)).to eq %w(./ ./LICENSE)
          expect(actual_sha1_of_license(expected_license_version)).to eq manifest_sha1_of_license(expected_license_version)
        end
      end

      it 'includes the NOTICE file if no LICENSE was present' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          File.delete('LICENSE')
          File.open('NOTICE', 'w') do |f|
            f.write('This is an example license file called NOTICE')
          end
          bosh_runner.run_in_current_dir("create release --force --with-tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize release dev_releases/test-release/test-release-0+dev.1.tgz")

          expected_license_version = 'af23c9afabd1eae2ff49db2545937b0467c61dd3'
          expect(out).to match(/\| license \| #{expected_license_version} \|/)
          expect(blobstore_tarball_listing(expected_license_version)).to eq %w(./ ./NOTICE)
          expect(actual_sha1_of_license(expected_license_version)).to eq manifest_sha1_of_license(expected_license_version)
        end
      end

      it 'works without a NOTICE or LICENSE present' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          File.delete('LICENSE')
          expect(File).to_not exist('NOTICE')
          bosh_runner.run_in_current_dir("create release --force --with-tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize release dev_releases/test-release/test-release-0+dev.1.tgz")
          expect(out).to_not match(/\| license \|/)
        end
      end

      it 'includes both NOTICE and LICENSE files when present' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          File.open('NOTICE', 'w') do |f|
            f.write('This is an example license file called NOTICE')
          end
          bosh_runner.run_in_current_dir("create release --force --with-tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize release dev_releases/test-release/test-release-0+dev.1.tgz")

          # an artifact's version and fingerprint are set identical in recent BOSH versions
          expected_license_version = '4b31262e2a9d1718eb36f6bb5c6b051df6c41ae1'
          expect(out).to match(/\| license \| #{expected_license_version} \|/)
          expect(blobstore_tarball_listing(expected_license_version)).to eq %w(./ ./LICENSE ./NOTICE)
          expect(actual_sha1_of_license(expected_license_version)).to eq manifest_sha1_of_license(expected_license_version)
        end
      end
    end
  end
end

require 'securerandom'
require_relative '../../spec_helper'

describe 'finalize release', type: :integration do
  include Bosh::Spec::CreateReleaseOutputParsers
  with_reset_sandbox_before_each
  SHA1_REGEXP = /^[0-9a-f]{40}$/

  before { setup_test_release_dir }

  describe 'release finalization' do
    context 'when finalizing a release that was built elsewhere' do
      it 'updates the .final_builds index for each job and package' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          bosh_runner.run_in_current_dir("finalize-release #{spec_asset('dummy-gocli-release.tgz')} --force")

          job_index = Psych.load_file(File.absolute_path('.final_builds/jobs/dummy/index.yml'))
          puts job_index
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
          out = table(bosh_runner.run_in_current_dir("finalize-release #{spec_asset('dummy-gocli-release.tgz')} --force", json: true))
          expect(out).to include(
            {"Job"=>"dummy/a2f501d07c3e96689185ee6ebe26c15d54d4849a", "SHA1"=>"16baf0c24e2dac2a21ccdcd4655be403a602f573", "Packages"=>""},
            {"Job"=>"dummy_with_bad_package/0c5fa6ab55ab9d030354a26c722fe3b6e83a775b", "SHA1"=>"6c67d40fa0df7a0ccfd49c873db533cb555b5f9c", "Packages"=>""},
            {"Job"=>"dummy_with_package/97a702673f3096a8251273cd7962ae39c0f63b7b", "SHA1"=>"e1f50e9b1fd987e1c36c1cc322cbbcbf51a577a8", "Packages"=>""},
            {"Job"=>"dummy_with_properties/c55e682be87812d0cb378c82150d619c0b9252e9", "SHA1"=>"415b4a9f29c21c1e193b540536fd15550fcefad3", "Packages"=>""},
            {"Job"=>"multi-monit-dummy/1441e36bc3a9888ae638baab4c6c19654cfdaf9e", "SHA1"=>"0059f555ab6e1e70e419665e19926a2290ffdd20", "Packages"=>""}
          )
          expect(out).to include(
            {"Package"=>"bad_package/e44d6e76a3cb74bfda0ec6d56dfbb334ca798209", "SHA1"=>"19b574c0f3d0d4910d4a4db85ede41ab9c734469", "Dependencies"=>""},
            {"Package"=>"dummy_package/a29b3b1174dc200826055732082bf21c7a765669", "SHA1"=>"42ade2b5b3495a989a8ffeeacc7e08c2387d29ba", "Dependencies"=>""}
          )
        end
      end

      it 'updates the releases index' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          bosh_runner.run_in_current_dir("finalize-release #{spec_asset('dummy-gocli-release.tgz')} --force")
          job_index = Psych.load_file(File.absolute_path('.final_builds/jobs/dummy/index.yml'))
          expect(job_index).to include('builds')
          expect(job_index['builds']).to include('a2f501d07c3e96689185ee6ebe26c15d54d4849a')
          expect(job_index['builds']['a2f501d07c3e96689185ee6ebe26c15d54d4849a']).to include('version', 'blobstore_id', 'sha1')
        end
      end

      it 'cannot create a final release without the blobstore configured' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          FileUtils.cp(spec_asset('empty_blobstore_config.yml'), 'config/final.yml')
          out = bosh_runner.run_in_current_dir("finalize-release #{spec_asset('dummy-gocli-release.tgz')} --force", json: true, failure_expected: true)
          expect(out).to match(/Expected non-empty 'blobstore.provider' in config .*\/config\/final\.yml/)
        end
      end

      it 'cannot create a final release without the blobstore secret configured' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          FileUtils.cp(spec_asset('blobstore_config_requiring_credentials.yml'), 'config/final.yml')
          out = bosh_runner.run_in_current_dir("finalize-release #{spec_asset('dummy-gocli-release.tgz')} --force", json: true, failure_expected: true)
          expect(out).to match(/Creating blob in inner blobstore:\\n    Generating blobstore ID:\\n      the client operates in read only mode. Change 'credentials_source' parameter value/)
        end
      end

      context 'when no previous releases have been made' do
        it 'finalize-release uploads the job & package blobs' do
          Dir.chdir(ClientSandbox.test_release_dir) do
            expect(Dir).to_not exist('releases')
            expect(Dir).to_not exist('dev_releases')
            expect(Dir).to_not exist('.final_builds')
            expect(Dir).to_not exist('.dev_builds')
            expect(Dir).to_not exist(ClientSandbox.blobstore_dir)

            bosh_runner.run_in_current_dir("finalize-release #{spec_asset('dummy-gocli-release.tgz')} --force")
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
          bosh_runner.run_in_current_dir("create-release --force --tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize-release dev_releases/test-release/test-release-0+dev.1.tgz --force")
          expect(out).to match("Added final release 'test-release/1'")
        end
      end

      it 'includes the LICENSE file' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          expect(File).to_not exist('NOTICE')
          File.open('LICENSE', 'w') do |f|
            f.write('This is an example license file')
          end
          bosh_runner.run_in_current_dir("create-release --force --tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize-release dev_releases/test-release/test-release-0+dev.1.tgz --force", json: true)

          expected_license_version = '7a59f7973cddfa0301ca34a29d4cc876247dd7de'
          expect(out).to match(/Added license 'license\/#{expected_license_version}'/)
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
          bosh_runner.run_in_current_dir("create-release --force --tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize-release dev_releases/test-release/test-release-0+dev.1.tgz --force", json: true)

          expected_license_version = 'af23c9afabd1eae2ff49db2545937b0467c61dd3'
          expect(out).to match(/Added license 'license\/#{expected_license_version}'/)
          expect(blobstore_tarball_listing(expected_license_version)).to eq %w(./ ./NOTICE)
          expect(actual_sha1_of_license(expected_license_version)).to eq manifest_sha1_of_license(expected_license_version)
        end
      end

      it 'works without a NOTICE or LICENSE present' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          File.delete('LICENSE')
          expect(File).to_not exist('NOTICE')
          bosh_runner.run_in_current_dir("create-release --force --tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize-release dev_releases/test-release/test-release-0+dev.1.tgz --force", json: true)
          expect(out).to_not match(/Added license/)
        end
      end

      it 'includes both NOTICE and LICENSE files when present' do
        Dir.chdir(ClientSandbox.test_release_dir) do
          File.open('NOTICE', 'w') do |f|
            f.write('This is an example license file called NOTICE')
          end
          bosh_runner.run_in_current_dir("create-release --force --tarball --name=test-release")
          out = bosh_runner.run_in_current_dir("finalize-release dev_releases/test-release/test-release-0+dev.1.tgz --force", json: true)

          # an artifact's version and fingerprint are set identical in recent BOSH versions
          expected_license_version = '4b31262e2a9d1718eb36f6bb5c6b051df6c41ae1'
          expect(out).to match(/Added license 'license\/#{expected_license_version}'/)
          expect(blobstore_tarball_listing(expected_license_version)).to eq %w(./ ./LICENSE ./NOTICE)
          expect(actual_sha1_of_license(expected_license_version)).to eq manifest_sha1_of_license(expected_license_version)
        end
      end
    end
  end
end

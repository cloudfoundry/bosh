require 'spec_helper'

describe 'cli: stemcell', type: :integration do
  with_reset_sandbox_before_each

  # NOTE: The dummy CPI derives stemcell IDs from the SHA1 of the contained
  # "image" file. If that file changes, update the value here using:
  # `shasum image`
  let(:expected_id) { '68aab7c44c857217641784806e2eeac4a3a99d1c' }

  it 'verifies a sample valid stemcell', no_reset: true do
    stemcell_filename = spec_asset('valid_stemcell.tgz')
    success = regexp("#{stemcell_filename}' is a valid stemcell")
    expect(bosh_runner.run("verify stemcell #{stemcell_filename}")).to match(success)
  end

  it 'points to an error when verifying an invalid stemcell', no_reset: true do
    stemcell_filename = spec_asset('stemcell_invalid_mf.tgz')
    failure = regexp("'#{stemcell_filename}' is not a valid stemcell")
    expect(bosh_runner.run("verify stemcell #{stemcell_filename}", failure_expected: true)).to match(failure)
  end

  # ~65s (possibly includes sandbox start)
  it 'can upload a stemcell and capture its metadata' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')

    target_and_login
    out = bosh_runner.run("upload stemcell #{stemcell_filename}")
    expect(out).to match /Stemcell uploaded and created/

    out = bosh_runner.run('stemcells')
    expect(out).to match /stemcells total: 1/i
    expect(out).to match /ubuntu-stemcell.+1/
    expect(out).to match regexp(expected_id.to_s)
    expect(out).to match /\| toronto-os \|/

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
  end

  # ~40s
  it 'can delete a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')

    target_and_login
    out = bosh_runner.run("upload stemcell #{stemcell_filename}")
    expect(out).to match /Stemcell uploaded and created/

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
    out = bosh_runner.run('delete stemcell ubuntu-stemcell 1')
    expect(out).to match /Deleted stemcell 'ubuntu-stemcell\/1'/
    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).not_to be_exists(stemcell_path)
  end

  it 'errors when --sha1 is used when uploading a local stemcell' do
    target_and_login
    expect {
      bosh_runner.run("upload stemcell #{spec_asset('valid_stemcell.tgz')} --sha1 shawone")
    }.to raise_error(RuntimeError, /Option '--sha1' is not supported for uploading local stemcell/)
  end

  context 'when stemcell is in use by a deployment' do
    it 'refuses to delete it' do
      deploy_from_scratch
      results = bosh_runner.run('delete stemcell ubuntu-stemcell 1', failure_expected: true)
      expect(results).to include("Stemcell 'ubuntu-stemcell/1' is still in use by: simple")
    end
  end

  describe 'uploading a stemcell that already exists' do
    before { target_and_login }

    context 'when the stemcell is local' do
      let(:local_stemcell_path) { spec_asset('valid_stemcell.tgz') }
      before { bosh_runner.run("upload stemcell #{local_stemcell_path}") }

      context 'when using the --skip-if-exists flag' do
        it 'tells the user and does not exit as a failure' do
          output = bosh_runner.run("upload stemcell #{local_stemcell_path} --skip-if-exists")
          expect(output).to include("Stemcell 'ubuntu-stemcell/1' already exists. Skipping upload.")
        end
      end

      context 'when NOT using the --skip-if-exists flag' do
        it 'tells the user and does exit as a failure' do
          output, exit_code = bosh_runner.run("upload stemcell #{local_stemcell_path}", {
            failure_expected: true,
            return_exit_code: true,
          })
          expect(output).to include("Stemcell 'ubuntu-stemcell/1' already exists")
          expect(exit_code).to eq(1)
        end
      end

      context 'when using the --fix flag' do
        it 'fails to execute when --skip-if-exists flag also used' do
          output, exit_code = bosh_runner.run("upload stemcell #{local_stemcell_path} --skip-if-exists --fix", {
            failure_expected: true,
            return_exit_code: true,
          })
          expect(output).to include("Option '--skip-if-exists' and option '--fix' should not be used together")
          expect(exit_code).to eq(1)
        end

        it 'fails to execute when --name flag also used' do
          output, exit_code = bosh_runner.run("upload stemcell #{local_stemcell_path} --name dummy --fix", {
             failure_expected: true,
             return_exit_code: true,
          })
          expect(output).to include("Options '--name' and '--version' should not be used together with option '--fix'")
          expect(exit_code).to eq(1)
        end

        it 'fails to execute when --version flag also used' do
          output, exit_code = bosh_runner.run("upload stemcell #{local_stemcell_path} --version 1 --fix", {
             failure_expected: true,
             return_exit_code: true,
          })
          expect(output).to include("Options '--name' and '--version' should not be used together with option '--fix'")
          expect(exit_code).to eq(1)
        end

        it 'fails to execute when --name and --version flags also used' do
          output, exit_code = bosh_runner.run("upload stemcell #{local_stemcell_path} --name dummy --version 1 --fix", {
             failure_expected: true,
             return_exit_code: true,
          })
          expect(output).to include("Options '--name' and '--version' should not be used together with option '--fix'")
          expect(exit_code).to eq(1)
        end


        it 'uploads stemcell' do
          # Check existing stemcell information
          out = bosh_runner.run('stemcells')
          expect(out).to match /stemcells total: 1/i
          expect(out).to match /ubuntu-stemcell.+1/
          expect(out).to match regexp(expected_id.to_s)
          expect(out).to match /\| toronto-os \|/

          stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
          expect(File).to be_exists(stemcell_path)

          # Upload a new stemcell with same version and name as the existing one, but is of different image content
          new_id = 'adc4232dcd3e06779c058224054d3d3238041367'
          new_local_stemcell_path = spec_asset('valid_stemcell_with_different_content.tgz')
          output = bosh_runner.run("upload stemcell #{new_local_stemcell_path} --fix")
          expect(output).to match /Stemcell uploaded and created/

          # Re-check the stemcell list and should return the new stemcell CID
          out = bosh_runner.run('stemcells')
          expect(out).to match /stemcells total: 1/i
          expect(out).to match /ubuntu-stemcell.+1/
          expect(out).to match regexp(new_id.to_s)
          expect(out).to match /\| toronto-os \|/

          # Check both old stemcell and new stemcll are in the storage
          stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
          expect(File).to be_exists(stemcell_path)

          stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{new_id}")
          expect(File).to be_exists(stemcell_path)
        end
      end
    end

    context 'when the stemcell is remote' do
      let(:file_server) { Bosh::Spec::LocalFileServer.new(spec_asset(''), file_server_port, logger) }
      let(:file_server_port) { current_sandbox.port_provider.get_port(:stemcell_repo) }

      before { file_server.start }
      after { file_server.stop }

      let(:stemcell_url) { file_server.http_url("valid_stemcell.tgz") }

      it 'downloads the file' do
        out = bosh_runner.run("upload stemcell #{stemcell_url}")
        expect(out).to match /Stemcell uploaded and created/

        out = bosh_runner.run('stemcells')
        expect(out).to match /stemcells total: 1/i
        expect(out).to match /ubuntu-stemcell.+1/
        expect(out).to match regexp(expected_id.to_s)

        stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
        expect(File).to be_exists(stemcell_path)
      end

      context 'when the URL is being redirected' do
        let(:redirect_url) { file_server.http_url("/redirect/to?/valid_stemcell.tgz") }

        it 'follows the redirect' do
          out = bosh_runner.run("upload stemcell #{redirect_url}")
          expect(out).to match /Stemcell uploaded and created/

          stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
          expect(File).to be_exists(stemcell_path)
        end
      end

      context 'when the stemcell has already been uploaded' do
        before { bosh_runner.run("upload stemcell #{stemcell_url}") }

        context 'when using the --skip-if-exists flag' do
          it 'tells the user and does not exit as a failure' do
            output = bosh_runner.run("upload stemcell #{stemcell_url} --skip-if-exists")
            expect(output).to include("already exists, skipped")
          end
        end

        context 'when NOT using the --skip-if-exists flag' do
          it 'tells the user and does not exit as a failure' do
            output = bosh_runner.run("upload stemcell #{stemcell_url}")
            expect(output).to include("already exists, skipped")
          end
        end

        context 'when using the --fix flag' do
          it 'fails to execute when --skip-if-exists flag also used' do
            output, exit_code = bosh_runner.run("upload stemcell #{stemcell_url} --skip-if-exists --fix", {
              failure_expected: true,
              return_exit_code: true,
            })
            expect(output).to include("Option '--skip-if-exists' and option '--fix' should not be used together")
            expect(exit_code).to eq(1)
          end

          it 'uploads stemcell' do
            # Check existing stemcell information
            out = bosh_runner.run('stemcells')
            expect(out).to match /stemcells total: 1/i
            expect(out).to match /ubuntu-stemcell.+1/
            expect(out).to match regexp(expected_id.to_s)
            expect(out).to match /\| toronto-os \|/

            stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
            expect(File).to be_exists(stemcell_path)

            # Upload a new stemcell with same version and name as the existing one, but is of different image content
            new_id = 'adc4232dcd3e06779c058224054d3d3238041367'
            new_stemcell_url = file_server.http_url("valid_stemcell_with_different_content.tgz")
            output = bosh_runner.run("upload stemcell #{new_stemcell_url} --fix")
            expect(output).to match /Stemcell uploaded and created/

            # Re-check the stemcell list and should return the new stemcell CID
            out = bosh_runner.run('stemcells')
            expect(out).to match /stemcells total: 1/i
            expect(out).to match /ubuntu-stemcell.+1/
            expect(out).to match regexp(new_id.to_s)
            expect(out).to match /\| toronto-os \|/

            # Check both old stemcell and new stemcll are in the storage
            stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
            expect(File).to be_exists(stemcell_path)

            stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{new_id}")
            expect(File).to be_exists(stemcell_path)
          end
        end
      end

      context 'when a sha1 is provided' do
        it 'accepts shas' do
          output = bosh_runner.run("upload stemcell #{stemcell_url} --sha1 bd0c5cc17b6753870f0e6b0155a2122e32649c22")
          expect(output).to include("Stemcell uploaded and created.")
        end

        it 'fails if the sha is incorrect' do
          output, exit_code = bosh_runner.run("upload stemcell #{stemcell_url} --sha1 shawone", {
            failure_expected: true,
            return_exit_code: true,
          })
          expect(output).to include("Error 50007")
          expect(exit_code).to eq(1)
        end
      end
    end
  end
end

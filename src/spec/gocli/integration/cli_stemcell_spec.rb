require_relative '../spec_helper'

describe 'cli: stemcell', type: :integration do
  with_reset_sandbox_before_each

  # NOTE: The dummy CPI derives stemcell IDs from the SHA1 of the contained
  # "image" file. If that file changes, update the value here using:
  # `shasum image`
  let(:expected_id) { '68aab7c44c857217641784806e2eeac4a3a99d1c' }

  # ~65s (possibly includes sandbox start)
  it 'can upload a stemcell and capture its metadata' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')

    out = bosh_runner.run("upload-stemcell #{stemcell_filename}")
    expect(out).to match /Save stemcell/
    expect(out).to match /Succeeded/

    out = table(bosh_runner.run('stemcells', json: true))
    expect(out).to eq([
      {
        'name' => 'ubuntu-stemcell',
        'version' => '1',
        'os' => 'toronto-os',
        'cpi' => '',
        'cid' => "#{expected_id}"
      }
    ])

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
  end

  context 'if cpi config is used' do
    it 'creates a stemcell for each configured cpi' do
      stemcell_filename = spec_asset('valid_stemcell.tgz')

      cpi_path = current_sandbox.sandbox_path(Bosh::Dev::Sandbox::Main::EXTERNAL_CPI)
      cpi_config_manifest = yaml_file('cpi_manifest', Bosh::Spec::Deployments.simple_cpi_config(cpi_path))
      bosh_runner.run("update-cpi-config #{cpi_config_manifest.path}")

      out = bosh_runner.run("upload-stemcell #{stemcell_filename}")
      expect(out).to include('Save stemcell')
      expect(out).to include('Succeeded')

      expect_table('stemcells', [
          {
              'name' => 'ubuntu-stemcell',
              'os' => 'toronto-os',
              'version' => '1',
              'cpi' => 'cpi-name1',
              'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
          },
          {
              'name' => 'ubuntu-stemcell',
              'os' => 'toronto-os',
              'version' => '1',
              'cpi' => 'cpi-name2',
              'cid' => '68aab7c44c857217641784806e2eeac4a3a99d1c'
          },

      ])
    end
  end

  # ~40s
  it 'can delete a stemcell' do
    stemcell_filename = spec_asset('valid_stemcell.tgz')

    out = bosh_runner.run("upload-stemcell #{stemcell_filename}")
    expect(out).to match /Save stemcell/
    expect(out).to match /Succeeded/

    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).to be_exists(stemcell_path)
    out = bosh_runner.run('delete-stemcell ubuntu-stemcell/1')
    expect(out).to match /Succeeded/
    stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
    expect(File).not_to be_exists(stemcell_path)
  end

  it 'allows --sha1 even when used during upload of a local stemcell' do
    out = bosh_runner.run("upload-stemcell #{spec_asset('valid_stemcell.tgz')} --sha1 shawone")
    expect(out).to match /Save stemcell/
    expect(out).to match /Succeeded/
  end

  context 'when stemcell is in use by a deployment' do
    it 'refuses to delete it' do
      deploy_from_scratch
      results = bosh_runner.run('delete-stemcell ubuntu-stemcell/1', failure_expected: true)
      expect(results).to include("Stemcell 'ubuntu-stemcell/1' is still in use by: simple")
    end
  end

  describe 'uploading a stemcell that already exists' do

    context 'when the stemcell is local' do
      let(:local_stemcell_path) { spec_asset('valid_stemcell.tgz') }
      before { bosh_runner.run("upload-stemcell #{local_stemcell_path}") }

      it 'tells the user and does not exit as a failure' do
        output = bosh_runner.run("upload-stemcell #{local_stemcell_path}")
        expect(output).to include("Stemcell 'ubuntu-stemcell/1' already exists.")
      end

      context 'when using the --fix flag' do
        it 'allows passing --name and --version flags' do
          output, exit_code = bosh_runner.run("upload-stemcell #{local_stemcell_path} --name dummy --version 1 --fix", {
             return_exit_code: true,
          })
          expect(output).to include('Succeeded')
          expect(exit_code).to eq(0)
        end

        it 'uploads stemcell' do
          # Check existing stemcell information
          out = table(bosh_runner.run('stemcells', json: true))
          expect(out).to eq([
            {
              'name' => 'ubuntu-stemcell',
              'version' => '1',
              'os' => 'toronto-os',
              'cpi' => '',
              'cid' => "#{expected_id}"
            }
          ])

          stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
          expect(File).to be_exists(stemcell_path)

          # Upload a new stemcell with same version and name as the existing one, but is of different image content
          new_id = 'adc4232dcd3e06779c058224054d3d3238041367'
          new_local_stemcell_path = spec_asset('valid_stemcell_with_different_content.tgz')
          output = bosh_runner.run("upload-stemcell #{new_local_stemcell_path} --fix")
          expect(output).to match /Save stemcell/
          expect(output).to match /Succeeded/

          # Re-check the stemcell list and should return the new stemcell CID
          out = table(bosh_runner.run('stemcells', json: true))
          expect(out).to eq([
            {
              'name' => 'ubuntu-stemcell',
              'version' => '1',
              'os' => 'toronto-os',
              'cpi' => '',
              'cid' => "#{new_id}"
            }
          ])

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

      let(:stemcell_url) { file_server.http_url('valid_stemcell.tgz') }

      it 'downloads the file' do
        out = bosh_runner.run("upload-stemcell #{stemcell_url}")
        expect(out).to match /Save stemcell/
        expect(out).to match /Succeeded/

        out = table(bosh_runner.run('stemcells', json: true))
        expect(out).to eq([
          {
            'name' => 'ubuntu-stemcell',
            'version' => '1',
            'os' => 'toronto-os',
            'cpi' => '',
            'cid' => "#{expected_id}"
          }
        ])

        stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
        expect(File).to be_exists(stemcell_path)
      end

      context 'when the URL is being redirected' do
        let(:redirect_url) { file_server.http_url('/redirect/to?/valid_stemcell.tgz') }

        it 'follows the redirect' do
          out = bosh_runner.run("upload-stemcell #{redirect_url}")
          expect(out).to match /Save stemcell/
          expect(out).to match /Succeeded/

          stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
          expect(File).to be_exists(stemcell_path)
        end
      end

      context 'when the stemcell has already been uploaded' do
        before { bosh_runner.run("upload-stemcell #{stemcell_url}") }

        it 'tells the user and does not exit as a failure' do
          output = bosh_runner.run("upload-stemcell #{stemcell_url}")
          expect(output).to include("already exists, skipped")
        end

        context 'when using the --fix flag' do
          it 'uploads stemcell' do
            # Check existing stemcell information
            out = table(bosh_runner.run('stemcells', json: true))
            expect(out).to eq([
              {
                'name' => 'ubuntu-stemcell',
                'version' => '1',
                'os' => 'toronto-os',
                'cpi' => '',
                'cid' => "#{expected_id}"
              }
            ])

            stemcell_path = File.join(current_sandbox.cloud_storage_dir, "stemcell_#{expected_id}")
            expect(File).to be_exists(stemcell_path)

            # Upload a new stemcell with same version and name as the existing one, but is of different image content
            new_id = 'adc4232dcd3e06779c058224054d3d3238041367'
            new_stemcell_url = file_server.http_url('valid_stemcell_with_different_content.tgz')
            output = bosh_runner.run("upload-stemcell #{new_stemcell_url} --fix")
            expect(output).to match /Save stemcell/
            expect(output).to match /Succeeded/


            # Re-check the stemcell list and should return the new stemcell CID
            out = table(bosh_runner.run('stemcells', json: true))
            expect(out).to eq([
            {
                'name' => 'ubuntu-stemcell',
                'version' => '1',
                'os' => 'toronto-os',
                'cpi' => '',
                'cid' => "#{new_id}"
              }
            ])

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
          output = bosh_runner.run("upload-stemcell #{stemcell_url} --sha1 73b51e1285240898f34b0fac22aba7ad4cc6ac65")
          expect(output).to match /Save stemcell/
          expect(output).to match /Succeeded/
        end

        it 'fails if the sha is incorrect' do
          output, exit_code = bosh_runner.run("upload-stemcell #{stemcell_url} --sha1 shawone", {
            failure_expected: true,
            return_exit_code: true,
          })
          expect(output).to match(/Expected stream to have digest 'shawone' but was '73b51e1285240898f34b0fac22aba7ad4cc6ac65'/)
          expect(exit_code).to eq(1)
        end

        it 'rejects the release when the sha1 is an unknown algorithm' do
          expect {
            bosh_runner.run("upload-stemcell #{stemcell_url} --sha1 'shaxyz:abcd1234'")
          }.to raise_error(RuntimeError, /Computing digest from stream: Unable to create digest of unknown algorithm 'shaxyz'/)
        end

        context 'when multiple digests are provided' do
          context 'when the digest is valid' do
            let(:multidigest_string) { 'sha256:5ca766c62c8eb49d698810096f091ad5b19167d6c2fcd592eb0a99a553b70526;sha1:73b51e1285240898f34b0fac22aba7ad4cc6ac65' }

            it 'accepts and verifies the multiple digests' do
              output = bosh_runner.run("upload-stemcell #{stemcell_url} --sha1 '#{multidigest_string}'")
              expect(output).to match /Save stemcell/
              expect(output).to match /Succeeded/
            end
          end

          context 'when the digest is valid' do
            let(:multidigest_string) { 'sha256:bad256;sha1:73b51e1285240898f34b0fac22aba7ad4cc6ac65' }

            it 'accepts and verifies the multiple digests' do
              expect {
                bosh_runner.run("upload-stemcell #{stemcell_url} --sha1 '#{multidigest_string}'")
              }.to raise_error(RuntimeError, /Error: Expected stream to have digest 'sha256:bad256' but was '/)
            end
          end
        end
      end
    end
  end
end

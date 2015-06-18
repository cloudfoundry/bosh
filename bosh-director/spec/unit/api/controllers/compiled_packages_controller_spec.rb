require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/compiled_packages_controller'
require 'tempfile'
require 'timecop'

module Bosh::Director
  describe Api::Controllers::CompiledPackagesController do
    include Rack::Test::Methods

    subject(:app) { described_class.new(config, Api::CompiledPackageGroupManager.new) }
    before { allow(Api::ResourceManager).to receive(:new) }
    let(:config) { Config.load_hash(Psych.load(spec_asset('test-director-config.yml'))) }
    
    describe 'POST', 'export' do
      def perform
        params = {
          stemcell_name:    'bosh-stemcell',
          stemcell_version: '123',
          release_name:     'cf-release',
          release_version:  '456',
        }
        post '/export', JSON.dump(params), { 'CONTENT_TYPE' => 'application/json' }
      end

      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        context 'when the specified stemcell and release exist' do
          before do
            Models::Stemcell.make(name: 'bosh-stemcell', version: '123')
            release = Models::Release.make(name: 'cf-release')
            Models::ReleaseVersion.make(release: release, version: '456')
          end

          let(:package_group) { instance_double('Bosh::Director::CompiledPackageGroup') }

          let(:exporter) do
            instance_double('Bosh::Director::CompiledPackagesExporter').tap do |cpe|
              allow(cpe).to receive(:export) { |path| FileUtils.touch(path) }
            end
          end

          before { allow(StaleFileKiller).to receive_messages(new: killer) }
          let(:killer) { instance_double('Bosh::Director::StaleFileKiller', kill: nil) }

          before do
            allow(CompiledPackageGroup).to receive(:new).and_return(package_group)
            blobstore_client = double('blobstore client')
            allow(App).to receive_message_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)

            allow(CompiledPackagesExporter).to receive(:new).with(package_group, blobstore_client).and_return(exporter)
          end

          it 'sets the mime type to application/x-compressed' do
            perform
            expect(last_response).to be_ok
            expect(last_response.content_type).to eq('application/x-compressed')
          end

          it 'creates a tarball with CompiledPackagesExporter and returns it' do
            expect(exporter).to receive(:export).with(anything) { |f| File.write(f, 'fake tgz content') }
            perform
            expect(last_response.body).to eq('fake tgz content')
          end

          it 'creates the output directory' do
            perform
            expect(File).to be_directory(File.join(Dir.tmpdir, 'compiled_packages'))
          end

          it 'passes the output directory to the exporter' do
            output_dir = File.join(Dir.tmpdir, 'compiled_packages')

            timestamp = Time.new
            output_path = File.join(output_dir, "compiled_packages_#{timestamp.to_f}.tar.gz")
            expect(exporter).to receive(:export).with(output_path)
            Timecop.freeze(timestamp) { perform }
          end

          it 'cleans up the stale exported packages with a StaleFileKiller' do
            output_dir = File.join(Dir.tmpdir, 'compiled_packages')
            expect(StaleFileKiller).to receive(:new).with(output_dir).and_return(killer)

            perform
            expect(killer).to have_received(:kill)
          end
        end

        context 'when the stemcell does not exist' do
          before do
            release = Models::Release.make(name: 'cf-release')
            Models::ReleaseVersion.make(release: release, version: '456')
          end

          it 'returns a 404' do
            perform
            expect(last_response).to be_not_found
          end
        end

        context 'when the release does not exist' do
          before { Models::Stemcell.make(name: 'bosh-stemcell', version: '123') }

          it 'returns a 404' do
            perform
            expect(last_response).to be_not_found
          end
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end

      context 'unauthenticated access' do
        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end
    end

    describe 'POST', '/import (multipart)' do
      def perform
        post '/import', { 'nginx_upload_path' => tar_path }, {'CONTENT_TYPE' => 'multipart/form-data'}
      end

      let(:tar_path) { "/tmp/archive-#{SecureRandom.uuid}.tgz" }
      before { FileUtils.touch(tar_path) }
      after { FileUtils.rm_f(tar_path) }

      before { Config.configure(Psych.load(spec_asset('test-director-config.yml'))) }

      context 'authenticated access' do
        before { authorize 'admin', 'admin' }

        it 'returns a task' do
          perform
          expect_redirect_to_queued_task(last_response)
        end
      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end

      context 'unauthenticated access' do
        it 'returns 401' do
          perform
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end

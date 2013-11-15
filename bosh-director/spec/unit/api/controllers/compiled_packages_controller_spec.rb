require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/compiled_packages_controller'
require 'tempfile'
require 'timecop'

module Bosh::Director
  describe Api::Controllers::CompiledPackagesController do
    include Rack::Test::Methods

    subject(:app) { described_class } # "app" is a Rack::Test hook

    before { Api::ResourceManager.stub(:new) }

    describe 'POST', '/compiled_package_groups/export' do
      def perform
        params = {
          stemcell_name:    'bosh-stemcell',
          stemcell_version: '123',
          release_name:     'cf-release',
          release_version:  '456',
        }
        post '/compiled_package_groups/export', JSON.dump(params), { 'CONTENT_TYPE' => 'application/json' }
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
              cpe.stub(:export) { |path| FileUtils.touch(path) }
            end
          end

          before { StaleFileKiller.stub(new: killer) }
          let(:killer) { instance_double('Bosh::Director::StaleFileKiller', kill: nil) }

          before do
            CompiledPackageGroup.stub(:new).and_return(package_group)
            blobstore_client = double('blobstore client')
            App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)

            CompiledPackagesExporter.stub(:new).with(package_group, blobstore_client).and_return(exporter)
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
            File.should be_directory(File.join(Dir.tmpdir, 'compiled_packages'))
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
            StaleFileKiller.should_receive(:new).with(output_dir).and_return(killer)

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

    describe 'POST', '/compiled_package_groups/import' do
      let(:tar_data) { 'tar data' }

      def perform
        post '/compiled_package_groups/import', tar_data, {'CONTENT_TYPE' => 'application/x-compressed'}
      end

      before do
        test_config = Psych.load(spec_asset('test-director-config.yml'))
        Config.configure(test_config)
      end

      context 'authenticated access' do
        let(:tar_data) { 'tar data' }

        before { authorize 'admin', 'admin' }

        it 'writes the compiled packages export file' do
          tempdir = Dir.mktmpdir
          Dir.stub(:mktmpdir).and_return(tempdir)

          perform

          export_path = File.join(tempdir, 'compiled_packages_export.tgz')

          expect(File.read(export_path)).to eq('tar data')
          FileUtils.rm_r(tempdir)
        end

        it 'enqueues a task' do
          File.stub(:open)
          Dir.stub(:mktmpdir).and_return('/tmp/path')

          task = instance_double('Bosh::Director::Models::Task', id: 1)

          job_queue = instance_double('Bosh::Director::JobQueue')
          JobQueue.stub(new: job_queue)

          expect(job_queue).to receive(:enqueue).with('admin', Jobs::ImportCompiledPackages, 'import compiled packages',
                                                      ['/tmp/path']).and_return(task)

          perform
        end

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

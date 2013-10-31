require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/compiled_packages_controller'
require 'tempfile'
require 'timecop'

module Bosh::Director
  describe Api::Controllers::CompiledPackagesController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::CompiledPackagesController } # "app" is a Rack::Test hook

    before do
      Api::ResourceManager.stub(:new)
    end

    describe 'GET', '/stemcells/:stemcell_name/:stemcell_version/releases/:release/:release_version/compiled_packages' do
      context 'unauthenticated access' do
        it 'returns 401' do
          get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

          expect(last_response.status).to eq(401)
        end
      end

      context 'accessing with invalid credentials' do
        it 'returns 401' do
          authorize 'invalid-user', 'invalid-password'

          get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

          expect(last_response.status).to eq(401)
        end
      end

      context 'authenticated access' do
        before do
          authorize 'admin', 'admin'

          Models::Stemcell.make(name: 'bosh-stemcell', version: '123')
          release = Models::Release.make(name: 'cf-release')
          Models::ReleaseVersion.make(release: release, version: '456')
        end

        context 'when the specified stemcell and release exist' do
          let(:package_group) { instance_double('Bosh::Director::CompiledPackageGroup') }
          let(:exporter) do
            double = instance_double('Bosh::Director::CompiledPackagesExporter')
            double.stub(:export) { |path| FileUtils.touch(path) }
            double
          end
          let(:killer) { double('stale file killer', kill: nil) }
          before { StaleFileKiller.stub(new: killer) }

          before do
            CompiledPackageGroup.stub(:new).and_return(package_group)
            blobstore_client = double('blobstore client')
            App.stub_chain(:instance, :blobstores, :blobstore).and_return(blobstore_client)

            CompiledPackagesExporter.stub(:new).with(package_group, blobstore_client).and_return(exporter)
          end

          it 'sets the mime type to application/x-compressed' do
            get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

            expect(last_response.status).to eq(200)
            expect(last_response.content_type).to eq('application/x-compressed')
          end

          it 'creates a tarball with CompiledPackagesExporter and returns it' do
            expect(exporter).to receive(:export).with(anything) { |f| File.write(f, 'fake tgz content') }
            get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'

            expect(last_response.body).to eq('fake tgz content')
          end

          it 'creates the output directory' do
            get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'
            File.should be_directory(File.join(Dir.tmpdir, 'compiled_packages'))
          end

          it 'passes the output directory to the exporter' do
            output_dir = File.join(Dir.tmpdir, 'compiled_packages')

            timestamp = Time.new
            output_path = File.join(output_dir, "compiled_packages_#{timestamp.to_f}.tar.gz")
            expect(exporter).to receive(:export).with(output_path)
            Timecop.freeze(timestamp) do
              get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'
            end
          end

          it 'cleans up the stale exported packages with a StaleFileKiller' do
            output_dir = File.join(Dir.tmpdir, 'compiled_packages')
            StaleFileKiller.should_receive(:new).with(output_dir).and_return(killer)

            get '/stemcells/bosh-stemcell/123/releases/cf-release/456/compiled_packages'
            expect(killer).to have_received(:kill)
          end
        end

        context 'when the stemcell does not exist' do
          it 'returns a 404' do
            get '/stemcells/invalid-stemcell/123/releases/cf-release/456/compiled_packages'

            expect(last_response.status).to eq(404)
          end
        end

        context 'when the release does not exist' do
          it 'returns a 404' do
            get '/stemcells/bosh-stemcell/123/releases/invalid-release/456/compiled_packages'

            expect(last_response.status).to eq(404)
          end
        end
      end
    end
  end
end

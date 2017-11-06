require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::PackagesController do
      include Rack::Test::Methods

      subject(:app) { linted_rack_app(described_class.new(config)) }
      before { allow(Api::ResourceManager).to receive(:new) }
      let(:config) { Config.load_hash(SpecHelper.spec_get_director_config) }

      describe 'POST', '/matches' do
        def perform
          post '/matches', YAML.dump(params), { 'CONTENT_TYPE' => 'text/yaml' }
        end

        def perform_matches_compiled(params_compiled)
          post '/matches_compiled', YAML.dump(params_compiled), { 'CONTENT_TYPE' => 'text/yaml' }
        end

        let(:params) { {'packages' => []} }

        context 'authenticated access' do
          before { authorize 'admin', 'admin' }

          context 'when database has packages missing their source blobs' do

            before do
              params.merge!('packages' => [
                  { 'fingerprint' => 'fake-pkg1-fingerprint' },
                  { 'fingerprint' => 'fake-pkg2-fingerprint' },
                  { 'fingerprint' => 'fake-pkg3-fingerprint' },
              ])

              release = Models::Release.make(name: 'fake-release-name')

              Models::Package.make(
                  release: release,
                  name: 'fake-pkg1',
                  version: 'fake-pkg1-version',
                  blobstore_id: 'fake-pkg1-blobstoreid',
                  sha1: 'fakepkg1sha',
                  fingerprint: 'fake-pkg1-fingerprint',
              )


              Models::Package.make(
                  release: release,
                  name: 'fake-pkg3',
                  version: 'fake-pkg3-version',
                  blobstore_id: 'fake-pkg3-blobstoreid',
                  sha1: 'fakepkg3sha',
                  fingerprint: 'fake-pkg3-fingerprint',
              )
            end

            it 'returns matching fingerprints only for packages that have source blobs' do
              perform
              expect(last_response.status).to eq(200)
              expect(JSON.load(last_response.body)).to eq(%w(fake-pkg1-fingerprint fake-pkg3-fingerprint))
            end
          end

          context 'when manifest is a hash and packages is an array' do
            context 'when manifest contains fingerprints' do
              before do
                params.merge!('packages' => [
                  { 'fingerprint' => 'fake-pkg1-fingerprint' },
                  { 'fingerprint' => 'fake-pkg2-fingerprint' },
                  { 'fingerprint' => 'fake-pkg3-fingerprint' },
                ])
              end

              context 'when there are packages with same fingerprint in the database' do
                before do
                  release = Models::Release.make(name: 'fake-release-name')

                  Models::Package.make(
                    release: release,
                    name: 'fake-pkg1',
                    version: 'fakepkg1sha',
                    fingerprint: 'fake-pkg1-fingerprint',
                  )

                  # No match for pkg2 in db

                  Models::Package.make(
                    release: release,
                    name: 'fake-pkg3',
                    version: 'fakepkg3sha',
                    fingerprint: 'fake-pkg3-fingerprint',
                  )
                end

                it 'returns list of matched fingerprints' do
                  perform
                  expect(last_response.status).to eq(200)
                  expect(JSON.load(last_response.body)).to eq(%w(fake-pkg1-fingerprint fake-pkg3-fingerprint))
                end
              end

              context 'when there are no packages with same fingerprint in the database' do
                before do
                  release = Models::Release.make(name: 'fake-release-name')

                  Models::Package.make(
                    release: release,
                    name: 'fake-pkg5',
                    version: 'fake-pkg5-sha',
                    fingerprint: 'fake-pkg5-fingerprint',
                  )
                end

                it 'returns empty array' do
                  perform
                  expect(last_response.status).to eq(200)
                  expect(JSON.parse(last_response.body)).to eq([])
                end
              end
            end

            context 'when manifest contains nil fingerprints' do
              before do
                params.merge!('packages' => [
                  { 'fingerprint' => nil },
                  { 'fingerprint' => 'fake-pkg2-fingerprint' },
                  { 'fingerprint' => 'fake-pkg3-fingerprint' },
                ])
              end

              before do
                release = Models::Release.make(name: 'fake-release-name')

                Models::Package.make(
                  release: release,
                  name: 'fake-pkg1',
                  version: 'fakepkg1sha',
                  fingerprint: 'fake-pkg1-fingerprint',
                )

                Models::Package.make(
                  release: release,
                  name: 'fake-pkg2',
                  version: 'fakepkg2sha',
                  fingerprint: nil, # set to nil explicitly
                )

                Models::Package.make(
                  release: release,
                  name: 'fake-pkg3',
                  version: 'fakepkg3sha',
                  fingerprint: 'fake-pkg3-fingerprint',
                )
              end

              it 'returns list of fingerprints ignoring nil fingerprint' do
                perform
                expect(last_response.status).to eq(200)
                expect(JSON.load(last_response.body)).to eq(%w(fake-pkg3-fingerprint))
              end
            end
          end

          context 'when manifest is a hash but packages is not an array' do
            before { params.merge!('packages' => nil) }

            it 'returns BadManifest error' do
              perform
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Manifest doesn\'t have a usable packages section',
              )
            end
          end

          context 'when manifest is not a hash' do
            let(:params) { nil }

            it 'returns BadManifest error' do
              perform
              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Manifest doesn\'t have a usable packages section',
              )
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

        context 'when matching compiled_packages' do
          before do
            authorize 'admin', 'admin'

            release = Models::Release.make(name: 'fake-release-name')

            package1 = Models::Package.make(
                release: release,
                name: 'fake-pkg1',
                version: 'fake-pkg1-version',
                sha1: 'fakepkg1sha',
                fingerprint: 'fake-pkg1-fingerprint',
            )

            Models::Package.make(
                release: release,
                name: 'fake-pkg2',
                version: 'fake-pkg2-version',
                sha1: 'fakepkg2sha',
                fingerprint: 'fake-pkg2-fingerprint',
            )

            Models::Package.make(
                release: release,
                name: 'fake-pkg3',
                version: 'fake-pkg3-version',
                sha1: 'fakepkg3sha',
                fingerprint: 'fake-pkg3-fingerprint',
            )

            package4 = Models::Package.make(
                release: release,
                name: 'fake-pkg4',
                version: 'fake-pkg4-version',
                sha1: 'fakepkg4sha',
                fingerprint: 'fake-pkg4-fingerprint',
            )

            Models::CompiledPackage.make(
                package_id: package1.id,
                blobstore_id: 'cpkg1_blobstore_id',
                sha1: 'cpkg1sha1',
                stemcell_os: 'ubuntu-trusty',
                stemcell_version: '3000',
                dependency_key: '[["fake-pkg2","fake-pkg2-version"],["fake-pkg3","fake-pkg3-version"]]',
            )

            Models::CompiledPackage.make(
                package_id: package4.id,
                blobstore_id: 'cpkg4_blobstore_id',
                sha1: 'cpkg4sha4',
                stemcell_os: 'ubuntu-trusty',
                stemcell_version: '3000',
                dependency_key: '[["fake-pkg1","fake-pkg1-version",[["fake-pkg2","fake-pkg2-version"],["fake-pkg3","fake-pkg3-version"]]]]',
            )
          end

          it 'returns list of matched fingerprints taking dependencies into account' do
            params_compiled = {'compiled_packages' => [
                { 'name' => 'fake-pkg1', 'version' => 'fake-pkg1-version', 'fingerprint' => 'fake-pkg1-fingerprint', 'stemcell' => 'ubuntu-trusty/3000', 'dependencies' => ['fake-pkg2', 'fake-pkg3'] },
                { 'name' => 'fake-pkg2', 'version' => 'fake-pkg2-version', 'fingerprint' => 'fake-pkg2-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
                { 'name' => 'fake-pkg3', 'version' => 'fake-pkg3-version', 'fingerprint' => 'fake-pkg3-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
            ]}
            perform_matches_compiled(params_compiled)
            expect(last_response.status).to eq(200)
            expect(JSON.load(last_response.body)).to eq(%w(fake-pkg1-fingerprint))

            params_compiled = {'compiled_packages' => [
                { 'name' => 'fake-pkg1', 'version' => 'fake-pkg1-version', 'fingerprint' => 'fake-pkg1-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
                { 'name' => 'fake-pkg2', 'version' => 'fake-pkg2-version', 'fingerprint' => 'fake-pkg2-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
                { 'name' => 'fake-pkg3', 'version' => 'fake-pkg3-version', 'fingerprint' => 'fake-pkg3-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
            ]}
            perform_matches_compiled(params_compiled)
            expect(last_response.status).to eq(200)
            expect(JSON.load(last_response.body)).to eq(%w())
          end

          it 'returns list of matched fingerprints including recursive dependency' do
            params_compiled = {'compiled_packages' => [
                { 'name' => 'fake-pkg1', 'version' => 'fake-pkg1-version', 'fingerprint' => 'fake-pkg1-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => ['fake-pkg2', 'fake-pkg3'] },
                { 'name' => 'fake-pkg2', 'version' => 'fake-pkg2-version', 'fingerprint' => 'fake-pkg2-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
                { 'name' => 'fake-pkg3', 'version' => 'fake-pkg3-version', 'fingerprint' => 'fake-pkg3-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => [] },
                { 'name' => 'fake-pkg4', 'version' => 'fake-pkg4-version', 'fingerprint' => 'fake-pkg4-fingerprint', 'stemcell' => 'ubuntu-trusty/3000','dependencies' => ['fake-pkg1'] },
            ]}
            perform_matches_compiled(params_compiled)
            expect(last_response.status).to eq(200)
            expect(JSON.load(last_response.body)).to eq(%w(fake-pkg1-fingerprint fake-pkg4-fingerprint))
          end

          it 'matches on stemcell for compiled package' do
            params_compiled = {'compiled_packages' => [
                { 'name' => 'fake-pkg1', 'version' => 'fake-pkg1-version', 'fingerprint' => 'fake-pkg1-fingerprint', 'stemcell' => 'centos-7/3001', 'dependencies' => ['fake-pkg2', 'fake-pkg3'] },
                { 'name' => 'fake-pkg2', 'version' => 'fake-pkg2-version', 'fingerprint' => 'fake-pkg2-fingerprint', 'stemcell' => 'centos-7/3001', 'dependencies' => [] },
                { 'name' => 'fake-pkg3', 'version' => 'fake-pkg3-version', 'fingerprint' => 'fake-pkg3-fingerprint', 'stemcell' => 'centos-7/3001', 'dependencies' => [] },
                { 'name' => 'fake-pkg4', 'version' => 'fake-pkg4-version', 'fingerprint' => 'fake-pkg4-fingerprint', 'stemcell' => 'ubuntu-trusty/3000', 'dependencies' => ['fake-pkg1'] },
            ]}
            perform_matches_compiled(params_compiled)
            expect(last_response.status).to eq(200)
            expect(JSON.load(last_response.body)).to eq(%w(fake-pkg4-fingerprint))
          end
        end
      end
    end
  end
end

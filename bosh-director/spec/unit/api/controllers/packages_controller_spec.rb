require 'spec_helper'
require 'rack/test'

module Bosh::Director
  module Api
    describe Controllers::PackagesController do
      include Rack::Test::Methods

      subject(:app) { described_class } # "app" is a Rack::Test hook

      before { allow(Api::ResourceManager).to receive(:new) }

      describe 'POST', '/matches' do
        def perform
          post '/matches', YAML.dump(params), { 'CONTENT_TYPE' => 'text/yaml' }
        end

        let(:params) { {'packages' => []} }

        context 'authenticated access' do
          before { authorize 'admin', 'admin' }

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
                    version: 'fake-pkg1-version',
                    version: 'fake-pkg1-sha',
                    fingerprint: 'fake-pkg1-fingerprint',
                  )

                  # No match for pkg2 in db

                  Models::Package.make(
                    release: release,
                    name: 'fake-pkg3',
                    version: 'fake-pkg3-version',
                    version: 'fake-pkg3-sha',
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
                    version: 'fake-pkg5-version',
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
                  version: 'fake-pkg1-version',
                  version: 'fake-pkg1-sha',
                  fingerprint: 'fake-pkg1-fingerprint',
                )

                Models::Package.make(
                  release: release,
                  name: 'fake-pkg2',
                  version: 'fake-pkg2-version',
                  version: 'fake-pkg2-sha',
                  fingerprint: nil, # set to nil explicitly
                )

                Models::Package.make(
                  release: release,
                  name: 'fake-pkg3',
                  version: 'fake-pkg3-version',
                  version: 'fake-pkg3-sha',
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
      end
    end
  end
end

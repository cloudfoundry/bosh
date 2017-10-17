require 'spec_helper'
require 'rack/test'
require 'bosh/director/api/controllers/configs_controller'

module Bosh::Director
  describe Api::Controllers::ConfigsController do
    include Rack::Test::Methods

    subject(:app) { Api::Controllers::ConfigsController.new(config) }
    let(:config) do
      config = Config.load_hash(SpecHelper.spec_get_director_config)
      identity_provider = Support::TestIdentityProvider.new(config.get_uuid_provider)
      allow(config).to receive(:identity_provider).and_return(identity_provider)
      config
    end

    describe 'GET', '/' do
      context 'with authenticated admin user' do
        before(:each) do
          authorize('admin', 'admin')
        end

        it 'returns all matching' do
          newest_config = 'new_config'

          Models::Config.make(
            content: 'some-yaml',
            created_at: Time.now - 3.days
          )

          Models::Config.make(
          content: 'some-other-yaml',
          created_at: Time.now - 2.days
          )

          Models::Config.make(
            name: 'my-config',
            content: newest_config,
            created_at: Time.now - 1.days
          )

          get '/?&latest=true'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(2)
          expect(JSON.parse(last_response.body)).to include(include('content' => 'some-other-yaml'))
          expect(JSON.parse(last_response.body)).to include(include('content' => newest_config))
        end

        context 'when name is given' do
          it 'returns the latest config with that name' do
            Models::Config.make(
                content: 'some-yaml',
                created_at: Time.now - 3.days
            )

            Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days
            )

            newest_config = 'new_config'
            Models::Config.make(
            name: 'my-config',
            content: newest_config,
            created_at: Time.now - 1.days
            )

            get '/?type=my-type&name=my-config&latest=true'
            expect(last_response.status).to eq(200)
            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        it 'returns the latest config' do
          Models::Config.make(
              content: 'some-yaml',
              created_at: Time.now - 3.days
          )

          Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days
          )

          newest_config = 'new_config'
          Models::Config.make(
              content: newest_config,
              created_at: Time.now - 1.days
          )

          get '/?type=my-type&latest=true'
          expect(last_response.status).to eq(200)
          expect(JSON.parse(last_response.body).count).to eq(1)
          expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
        end

        context 'when no records match the filters' do
          it 'returns empty' do

            get '/?type=my-type&name=notExisting&latest=true'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result).to eq([])
          end
        end

        context 'when no type is given' do
          it 'does not filter by type' do
            Models::Config.make(
              content: 'some-other-yaml',
              created_at: Time.now - 2.days
            )

            newest_config = 'new_config'
            Models::Config.make(
              content: newest_config,
              created_at: Time.now - 1.days
            )

            get '/?latest=true'

            expect(JSON.parse(last_response.body).count).to eq(1)
            expect(JSON.parse(last_response.body).first['content']).to eq(newest_config)
          end
        end

        context 'when no latest param is given' do
          it 'return 400' do
            get '/?type=my-type&name=some-name'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40001)
            expect(JSON.parse(last_response.body)['description']).to eq("'latest' is required")
          end
        end

        context 'when latest param is given and has wrong value' do
          it 'return 400' do
            get '/?type=my-type&name=some-name&latest=foo'

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40005)
            expect(JSON.parse(last_response.body)['description']).to eq("'latest' must be 'true' or 'false'")
          end
        end

        context 'when latest is false' do
          it 'returns the history of all matching configs' do
            config1 = Models::Config.make
            Models::Config.make

            get '/?type=my-type&latest=false'

            expect(last_response.status).to eq(200)

            result = JSON.parse(last_response.body)
            expect(result.class).to be(Array)
            expect(result.size).to eq(2)
            expect(result).to include({
                'content' => config1.content,
                'id' => config1.id,
                'type' => config1.type,
                'name' => config1.name
            })
          end
        end
      end

      context 'without an authenticated user' do
        it 'denies access' do
          expect(get('/').status).to eq(401)
        end
      end

      context 'when user is reader' do
        before { basic_authorize('reader', 'reader') }

        it 'permits access' do
          expect(get('/?type=my-type&latest=true').status).to eq(200)
        end
      end
    end

    describe 'POST', '/' do
      let(:config_data) { "fake-config" }
      let(:content) {
        YAML.dump({ 'name' => 'my-name', 'type' => 'my-type', 'content' => config_data })
       }

      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        it 'creates a new config' do
          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)

          expect(JSON.parse(last_response.body)).to eq(
            {
              'id' => Bosh::Director::Models::Config.first.id,
              'type' => 'my-type',
              'name' => 'my-name',
              'content' => config_data
            }
          )
        end

        it 'creates a new config with whitespace preceding content' do
          expect {
            post '/', YAML.dump({ 'name' => 'my-name', 'type' => 'my-type', 'content' => '    a: 123' }), {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(0).to(1)

          expect(last_response.status).to eq(201)

          expect(JSON.parse(last_response.body)).to eq(
            {
              'id' => Bosh::Director::Models::Config.first.id,
              'type' => 'my-type',
              'name' => 'my-name',
              'content' => '    a: 123'
            }
          )
        end

        it 'creates new config and does not update existing ' do
          post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(201)

          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Config, :count).from(1).to(2)

          expect(last_response.status).to eq(201)
        end

        it 'gives a nice error when request body is not a valid yml' do
          post '/', "}}}i'm not really yaml, hah!", {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)['code']).to eq(440001)
          expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded body: ')
        end

        it 'gives a nice error when request body is empty' do
          post '/', '', {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)).to eq(
              'code' => 440001,
              'description' => 'Body should not be empty',
          )
        end

        it 'gives a nice error when request body is invalid config yaml' do
          post '/', '---', {'CONTENT_TYPE' => 'text/yaml'}

          expect(last_response.status).to eq(400)
          expect(JSON.parse(last_response.body)).to eq(
            'code' => 710000,
            'description' => 'YAML hash expected',
          )
        end

        it 'creates a new event' do
          expect {
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
          }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
          event = Bosh::Director::Models::Event.first
          expect(event.object_type).to eq('config/my-type')
          expect(event.object_name).to eq('my-name')
          expect(event.action).to eq('create')
          expect(event.user).to eq('admin')
        end

        context 'when using config with missing content' do
         let(:content) {
           YAML.dump({ 'type' => 'my-type', 'name' => 'my-name', 'content' => {} })
         }

          it 'creates a new event with error' do
            expect {
              post '/', content, {'CONTENT_TYPE' => 'text/yaml'}
            }.to change(Bosh::Director::Models::Event, :count).from(0).to(1)
            event = Bosh::Director::Models::Event.first
            expect(event.object_type).to eq('config/my-type')
            expect(event.object_name).to eq('my-name')
            expect(event.action).to eq('create')
            expect(event.user).to eq('admin')
            expect(event.error).to eq("'content' is required")
          end
        end

        context 'when yaml enclosure is invalid for content' do
          let(:content) { "---\nname: n\ntype: t\ncontent:\n  a: 1\n" }

          it 'return 400' do
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(710000)
            expect(JSON.parse(last_response.body)['description']).to eq("'content' must be a string")
          end
        end

        context 'when `type` argument is missing' do
          let(:content) {
            YAML.dump({'name' => 'my-name', 'content' => {} })
          }

          it 'return 400' do
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40001)
            expect(JSON.parse(last_response.body)['description']).to eq("'type' is required")
          end
        end

        context 'when `name` argument is missing' do
          let(:content) {
            YAML.dump({'type' => 'my-type', 'content' => {} })
          }

          it 'return 400' do
            post '/', content, {'CONTENT_TYPE' => 'text/yaml'}

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['code']).to eq(40001)
            expect(JSON.parse(last_response.body)['description']).to eq("'name' is required")
          end
        end
      end

      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(post('/', content, {'CONTENT_TYPE' => 'text/yaml'}).status).to eq(401)
        end
      end
    end

    describe 'DELETE', '/' do
      describe 'when user has readonly access' do
        before { basic_authorize 'reader', 'reader' }

        it 'denies access' do
          expect(delete('/?type=my-type&name=my-name').status).to eq(401)
        end
      end

      describe 'when user has admin access' do
        before { authorize('admin', 'admin') }

        context 'when type and name are given' do
          context 'when config exists' do
            before do
              Models::Config.make(
                type: 'my-type',
                name: 'my-name'
              )
            end

            it 'deletes the config' do
              expect(delete('/?type=my-type&name=my-name').status).to eq(204)

              configs = JSON.parse(get('/?type=my-type&name=my-name&latest=false').body)

              expect(configs.count).to eq(0)
            end
          end

          context "when there is no config matching given 'type' and 'name'" do
            it 'responds with 404' do
              expect(delete('/?type=my-type&name=my-name').status).to eq(404)
            end
          end
        end

        context "when 'type' parameter is missing" do
          it 'responds with 400' do
            response = delete('/?name=my-name')

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'type' is required")
          end
        end

        context "when 'name' parameter is missing" do
          it 'responds with 400' do
            response = delete('/?type=my-type')

            expect(response.status).to eq(400)
            expect(JSON.parse(response.body)['description']).to eq("'name' is required")
          end
        end
      end
    end

    describe 'diff' do

      let(:config_hash_with_one_az) {
        {
          'azs' => [
            {
              'name' => 'az1',
              'properties' => {}
            }
          ]
        }
      }

      let(:config_hash_with_two_azs) {
        {
          'azs' => [
            {
              'name' => 'az1',
              'properties' => {}
            },
            {
              'name' => 'az2',
              'properties' => {
                'some-key' => 'some-value'
              }
            }
          ]
        }
      }

      let(:new_config) do
        YAML.dump({
          'type' => 'myType',
          'name' => 'myName',
          'content' => new_content
        })
      end

      let(:new_content) { "---\n" }

      context 'authenticated access' do

        before { authorize 'admin', 'admin' }

        context 'when diffing yields an error' do
          let(:new_content) {'{}'}
          it 'returns 400 with an empty diff and an error message if the diffing fails' do
            allow_any_instance_of(Bosh::Director::Changeset).to receive(:diff).and_raise('Oooooh crap')

            post '/diff', new_config, { 'CONTENT_TYPE' => 'text/yaml' }

            expect(last_response.status).to eq(400)
            expect(JSON.parse(last_response.body)['diff']).to eq([])
            expect(JSON.parse(last_response.body)['error']).to include('Unable to diff config content')
          end
        end

        context 'when there is a previous config with given name and type' do

          before do
            Models::Config.create(
              type: 'myType',
              name: 'myName',
              raw_manifest: config_hash_with_two_azs
            )
          end

          context 'when uploading an empty cloud config' do
            let(:new_content) { "---\n" }

            it 'returns the diff' do

              post(
                '/diff',
                new_config,
                { 'CONTENT_TYPE' => 'text/yaml' }
              )

              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:","removed"],["- name: az1","removed"],["  properties: {}","removed"],["- name: az2","removed"],["  properties:","removed"],["    some-key: \"<redacted>\"","removed"]]}')
            end
          end

          context 'when there is no diff' do
            let(:new_content) { YAML.dump(config_hash_with_two_azs) }

            it 'returns empty diff' do

              post(
                '/diff',
                new_config,
                {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.body).to eq('{"diff":[]}')
            end
          end

          context 'when there is a diff' do
            let(:new_content) { YAML.dump(config_hash_with_one_az) }

            it 'returns the diff' do
              post(
                '/diff',
                new_config,
                {'CONTENT_TYPE' => 'text/yaml'}
              )
              expect(last_response.status).to eq(200)
              expect(last_response.body).to eq('{"diff":[["azs:",null],["- name: az2","removed"],["  properties:","removed"],["    some-key: \"<redacted>\"","removed"]]}')
            end
          end

          context 'when invalid content YAML is given' do
            let(:new_content) { "}}}i'm not really yaml, hah!" }
            it 'gives a nice error when request body is not a valid yml' do

              post('/diff', new_config, {'CONTENT_TYPE' => 'text/yaml'})

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440001)
              expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded config content: ')
            end
          end

          context 'when the body is not valid YAML' do
            it 'gives a nice error when request body is not a valid yml' do
              post('/diff', "}}}i'm not really yaml, hah!", { 'CONTENT_TYPE' => 'text/yaml' })

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['code']).to eq(440001)
              expect(JSON.parse(last_response.body)['description']).to include('Incorrect YAML structure of the uploaded body: ')
            end
          end

          context 'when request body is empty' do
            it 'gives a nice error ' do
              post '/diff', '', {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Body should not be empty',
              )
            end
          end

          context 'when config content is empty' do
            let(:new_content) { '' }
            it 'gives a nice error ' do
              post '/diff', new_config, {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)).to eq(
                'code' => 440001,
                'description' => 'Config content should not be empty'
              )
            end
          end

          context 'when config content is not a hash' do
            let(:new_content) { 'I am not a hash' }
            it 'errors' do
              post '/diff', new_config, {'CONTENT_TYPE' => 'text/yaml'}

              expect(last_response.status).to eq(400)
              expect(JSON.parse(last_response.body)['error']).to eq('Config content must be a Hash')
            end
          end
        end

        context 'when there is no previous cloud config' do
          let(:new_content) { YAML.dump(config_hash_with_one_az) }
          it 'returns the diff' do
            post(
              '/diff',
              new_config,
              {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  properties: {}","added"]]}')
          end
        end

        context 'when previous config is nil' do
          before do
            Models::Config.create(
              type: 'myType',
              name: 'myName',
              raw_manifest: nil
            )
          end
          let(:new_content) { YAML.dump(config_hash_with_one_az) }

          it 'returns the diff' do
            post(
              '/diff',
              new_config,
              {'CONTENT_TYPE' => 'text/yaml'}
            )
            expect(last_response.status).to eq(200)
            expect(last_response.body).to eq('{"diff":[["azs:","added"],["- name: az1","added"],["  properties: {}","added"]]}')
          end
        end

      end

      context 'accessing with invalid credentials' do
        before { authorize 'invalid-user', 'invalid-password' }

        it 'returns 401' do
          post '/diff', {}.to_yaml, {'CONTENT_TYPE' => 'text/yaml'}
          expect(last_response.status).to eq(401)
        end
      end
    end
  end
end

require 'spec_helper'

describe Bosh::Cli::Client::Director do
  DUMMY_TARGET = 'https://target.example.com:8080'

  before do
    allow(Resolv).to receive(:getaddresses).with('target.example.com').and_return(['127.0.0.1'])
    @director = Bosh::Cli::Client::Director.new(DUMMY_TARGET, credentials)
    allow(@director).to receive(:retry_wait_interval).and_return(0)
  end

  let(:credentials) { Bosh::Cli::Client::BasicCredentials.new('user', 'pass') }

  describe 'checking availability' do
    it 'waits until director is ready' do
      expect(@director).to receive(:get_status).and_raise(Bosh::Cli::DirectorError).ordered
      expect(@director).to receive(:get_status).and_return(cpi: 'aws').ordered

      @director.wait_until_ready
    end
  end

  describe 'fetching status' do
    it 'tells if user is authenticated' do
      expect(@director).to receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate('user' => 'adam')])
      expect(@director.authenticated?).to eql(true)
    end

    it 'tells if user not authenticated' do
      expect(@director).to receive(:get).with('/info', 'application/json').
        and_return([403, 'Forbidden'])
      expect(@director.authenticated?).to eql(false)

      expect(@director).to receive(:get).with('/info', 'application/json').
        and_return([500, 'Error'])
      expect(@director.authenticated?).to eql(false)

      expect(@director).to receive(:get).with('/info', 'application/json').
        and_return([404, 'Not Found'])
      expect(@director.authenticated?).to eql(false)

      expect(@director).to receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate('user' => nil, 'version' => 1)])
      expect(@director.authenticated?).to eql(false)

      # Backward compatibility
      expect(@director).to receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate('status' => 'ZB')])
      expect(@director.authenticated?).to eql(true)
    end
  end

  describe '#login' do
    before do
      @director = Bosh::Cli::Client::Director.new(DUMMY_TARGET)
    end

    context 'new director versions (have version key)' do
      it 'returns true when status has a user key' do
        allow(@director).to receive(:get).with('/info', 'application/json').
            and_return([200, JSON.generate('version' => 'newer directors', 'user' => 'new user')])

        expect(@director.login('new user', 'new password')).to eq(true)
      end

      it 'returns false if theres no user key' do
        allow(@director).to receive(:get).with('/info', 'application/json').
            and_return([200, JSON.generate('version' => 'newer directors')])
        expect(@director.login('new user', 'new password')).to eq(false)
      end

      it 'returns false if we get a non-200' do
        expect(@director).to receive(:get).with('/info', 'application/json').
            and_return([403, 'Forbidden'])
        expect(@director.login('new user', 'new password')).to eq(false)

        expect(@director).to receive(:get).with('/info', 'application/json').
            and_return([500, 'Error'])
        expect(@director.login('new user', 'new password')).to eq(false)

        expect(@director).to receive(:get).with('/info', 'application/json').
            and_return([404, 'Not Found'])
        expect(@director.login('new user', 'new password')).to eq(false)
      end
    end

    context 'old director versions (no version key)' do
      it 'returns true even if theres no user key, as long as theres no version key' do
        allow(@director).to receive(:get).with('/info', 'application/json').
            and_return([200, JSON.generate({})])

        expect(@director.login('new user', 'new password')).to eq(true)
      end

      it 'returns false if we get a non-200' do
        expect(@director).to receive(:get).with('/info', 'application/json').
            and_return([403, 'Forbidden'])
        expect(@director.login('new user', 'new password')).to eq(false)

        expect(@director).to receive(:get).with('/info', 'application/json').
            and_return([500, 'Error'])
        expect(@director.login('new user', 'new password')).to eq(false)

        expect(@director).to receive(:get).with('/info', 'application/json').
            and_return([404, 'Not Found'])
        expect(@director.login('new user', 'new password')).to eq(false)
      end    end

    it 'returns false when login succeeds on old directors' do
      allow(@director).to receive(:get).with('/info', 'application/json').
          and_return([200, JSON.generate('user' => 'new user')])

      expect(@director.login('new user', 'new password')).to eq(true)
    end
  end

  describe 'authorization' do
    context 'using user/password credentials' do
      let(:request_headers) { { 'Content-Type' => 'application/json', 'Authorization' => 'Basic dXNlcjpwYXNz' } }

      it 'adds authorization header with basic auth' do
        stub_request(:get, 'https://127.0.0.1:8080/info').
          with(headers: request_headers).to_return(body: '{}', status: 200)

        @director.get_status
      end
    end

    context 'using token credentials' do
      let(:credentials) { Bosh::Cli::Client::UaaCredentials.new('bearer token') }
      let(:request_headers) { { 'Content-Type' => 'application/json', 'Authorization' => 'bearer token' } }

      it 'adds authorization header with UAA token' do
        stub_request(:get, 'https://127.0.0.1:8080/info').
          with(headers: request_headers).to_return(body: '{}', status: 200)

        @director.get_status
      end
    end

    context 'when credentials are not provided' do
      let(:credentials) { nil }
      let(:request_headers) { { 'Content-Type' => 'application/json' } }

      it 'adds authorization header with UAA token' do
        stub_request(:get, 'https://127.0.0.1:8080/info').
          with(headers: request_headers).to_return(body: '{}', status: 200)

        @director.get_status
      end
    end
  end

  describe 'interface REST API' do
    it 'has helper methods for HTTP verbs which delegate to generic request' do
      [:get, :put, :post, :delete].each do |verb|
        expect(@director).to receive(:request).with(verb, :arg1, :arg2, nil, {}, {})
        @director.send(verb, :arg1, :arg2)
      end
    end
  end

  describe 'API calls' do
    let(:task_number) { 232 }

    describe '#list_vms' do
      let(:vms) do
        [{
            'agent_id' => 'agent-id1',
            'cid'      => 'vm-id1',
            'job'      => 'dummy',
            'index'    => 0 },
          {
            'agent_id' => 'agent-id2',
            'cid'      => 'vm-id2',
            'job'      => 'dummy',
            'index'    => 1
          },
          {
            'agent_id' => 'agent-id3',
            'cid'      => 'vm-id3',
            'job'      => 'dummy',
            'index'    => 2
          }]
      end

      let(:response_body) { JSON.generate(vms) }

      before do
        stub_request(:get, 'https://127.0.0.1:8080/deployments/foo/vms').
          with(headers: request_headers).to_return(body: response_body, status: 200)
      end

      context 'using user/password credentials' do
        let(:request_headers) { { 'Content-Type' => 'application/json', 'Authorization' => 'Basic dXNlcjpwYXNz' } }

        it 'lists vms for a given deployment' do
          expect(@director.list_vms('foo')).to eq vms
        end
      end
    end

    it 'creates user' do
      expect(@director).to receive(:post).
        with('/users', 'application/json',
             JSON.generate('username' => 'joe', 'password' => 'pass')).
        and_return(true)
      @director.create_user('joe', 'pass')
    end

    it 'deletes users' do
      expect(@director).to receive(:delete).
        with('/users/joe').
        and_return([204, '', {}])
      expect(@director.delete_user('joe')).to eql(true)
    end

    it 'fails to delete users' do
      expect(@director).to receive(:delete).
        with('/users/joe').
        and_return([500, '', {}])
      expect(@director.delete_user('joe')).to eql(false)
    end

    it 'uploads local stemcell' do
      expect(@director).to receive(:upload_and_track).
        with(:post, '/stemcells', '/path',
             { :content_type => 'application/x-compressed' }).
        and_return(true)
      @director.upload_stemcell('/path')
    end

    it 'uploads remote stemcell' do
      expect(@director).to receive(:request_and_track).
        with(:post, '/stemcells',
             { :content_type => 'application/json',
               :payload      => JSON.generate('location' => 'stemcell_uri') }).
        and_return(true)
      @director.upload_remote_stemcell('stemcell_uri')
    end

    it 'lists stemcells' do
      expect(@director).to receive(:get).with('/stemcells', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_stemcells
    end

    it 'lists releases' do
      expect(@director).to receive(:get).with('/releases', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_releases
    end

    it 'lists deployments' do
      expect(@director).to receive(:get).with('/deployments', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_deployments
    end

    it 'lists errands in current deployment' do
      expect(@director).to receive(:get).with('/deployments/fake-deployment/errands', 'application/json').
        and_return([200, JSON.generate([{"name" => "errand"}]), {}])
      @director.list_errands("fake-deployment")
    end

    it 'lists currently running tasks' do
      expect(@director).to receive(:get).
        with('/tasks?state=processing,cancelling,queued&verbose=1',
             'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_running_tasks
    end

    it 'lists recent tasks' do
      expect(@director).to receive(:get).
        with('/tasks?limit=30&verbose=1', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_recent_tasks

      expect(@director).to receive(:get).
        with('/tasks?limit=100000&verbose=1', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_recent_tasks(100000)

      expect(@director).to receive(:get).
        with('/tasks?limit=50&verbose=2', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_recent_tasks(50, 2)
    end

    it 'uploads local release' do
      expect(@director).to receive(:upload_and_track).
        with(:post, '/releases', '/path', hash_including(
               :content_type => 'application/x-compressed')).
        and_return(true)
      @director.upload_release('/path')
    end

    it 'uploads local release (with options)' do
      expect(@director).to receive(:upload_and_track).
        with(:post, '/releases?rebase=true', '/path', hash_including(
               :content_type => 'application/x-compressed')).
        and_return(true)
      @director.upload_release('/path', rebase: true)
    end

    it 'uploads remote release' do
      expect(@director).to receive(:request_and_track).
        with(:post, '/releases', hash_including(
               :content_type => 'application/json',
               :payload      => JSON.generate('location' => 'release_uri'))).
        and_return(true)
      @director.upload_remote_release('release_uri')
    end

    it 'uploads remote release (with options)' do
      expect(@director).to receive(:request_and_track).
        with(:post, '/releases?rebase=true&skip_if_exists=true', hash_including(
               :content_type => 'application/json',
               :payload      => JSON.generate('location' => 'release_uri'))).
        and_return(true)
      @director.upload_remote_release('release_uri', rebase: true, skip_if_exists: true)
    end

    it 'gets release info' do
      expect(@director).to receive(:get).
        with('/releases/foo', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.get_release('foo')
    end

    it 'gets deployment info' do
      expect(@director).to receive(:get).
        with('/deployments/foo', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.get_deployment('foo')
    end

    it 'deletes stemcell' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/stemcells/ubuntu/123', {}).and_return(true)
      @director.delete_stemcell('ubuntu', '123')
    end

    it 'deletes stemcell with force' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/stemcells/ubuntu/123?force=true', {}).and_return(true)
      @director.delete_stemcell('ubuntu', '123', :force => true)
    end

    it 'deletes deployment' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/deployments/foo', {}).and_return(true)
      @director.delete_deployment('foo')
    end

    it 'deletes release (non-force)' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/releases/za', {}).and_return(true)
      @director.delete_release('za')
    end

    it 'deletes release (force)' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/releases/zb?force=true', {}).and_return(true)
      @director.delete_release('zb', :force => true)
    end

    it 'deploys' do
      expect(@director).to receive(:request_and_track).
        with(:post, '/deployments',
             { :content_type => 'text/yaml', :payload => 'manifest' }).
        and_return(true)
      @director.deploy('manifest')
    end

    it 'changes job state' do
      expect(@director).to receive(:request_and_track).
        with(:put, '/deployments/foo/jobs/dea?state=stopped',
             { :content_type => 'text/yaml', :payload => 'manifest' }).
        and_return(true)
      @director.change_job_state('foo', 'manifest', 'dea', nil, 'stopped')
    end

    it 'changes job instance state' do
      expect(@director).to receive(:request_and_track).
        with(:put, '/deployments/foo/jobs/dea/0?state=detached',
             { :content_type => 'text/yaml', :payload => 'manifest' }).
        and_return(true)
      @director.change_job_state('foo', 'manifest', 'dea', 0, 'detached')
    end

    it 'changes job instance resurrection state' do
      expect(@director).to receive(:request).with(:put,
          '/deployments/foo/jobs/dea/0/resurrection',
          'application/json',
          '{"resurrection_paused":true}',
          {},
          {})
      @director.change_vm_resurrection('foo', 'dea', 0, true)
    end

    it 'change resurrection globally' do
      expect(@director).to receive(:request).with(:put,
          '/resurrection',
          'application/json',
          '{"resurrection_paused":false}',
          {},
          {})
      @director.change_vm_resurrection_for_all(false)
    end

    it 'gets task state' do
      expect(@director).to receive(:get).
        with("/tasks/#{task_number}").
        and_return([200, JSON.generate({ 'state' => 'done' })])
      expect(@director.get_task_state(task_number)).to eql('done')
    end

    it 'gets task output' do
      expect(@director).to receive(:get).
        with("/tasks/#{task_number}/output", nil,
             nil, { 'Range' => 'bytes=42-' }).
        and_return([206, 'test', { :content_range => 'bytes 42-56/100' }])
      expect(@director.get_task_output(task_number, 42)).to eql(['test', 57])
    end

    it "doesn't set task output body and new offset if there's a byte range unsatisfiable response" do
      expect(@director).to receive(:get).
        with("/tasks/#{task_number}/output", nil,
             nil, { 'Range' => 'bytes=42-' }).
        and_return([416, 'Byte range unsatisfiable', { :content_range => 'bytes */100' }])
      expect(@director.get_task_output(task_number, 42)).to eql([nil, nil])
    end

    it "doesn't set task output new offset if it wasn't a partial response" do
      expect(@director).to receive(:get).
        with("/tasks/#{task_number}/output", nil, nil,
             { 'Range' => 'bytes=42-' }).
        and_return([200, 'test'])
      expect(@director.get_task_output(task_number, 42)).to eql(['test', nil])
    end

    it 'know how to find time difference with director' do
      now         = Time.now
      server_time = now - 100
      allow(Time).to receive(:now).and_return(now)

      expect(@director).to receive(:get).with('/info').
        and_return([200, JSON.generate('version' => 1),
                    { :date => server_time.rfc822 }])
      expect(@director.get_time_difference.to_i).to eql(100)
    end

    it 'takes snapshot for a deployment' do
      expect(@director).to receive(:request_and_track).
        with(:post, '/deployments/foo/snapshots', {}).
        and_return(true)
      @director.take_snapshot('foo')
    end

    it 'takes snapshot for a job and index' do
      expect(@director).to receive(:request_and_track).
        with(:post, '/deployments/foo/jobs/bar/0/snapshots', {}).
        and_return(true)
      @director.take_snapshot('foo', 'bar', '0')
    end

    it 'lists snapshots for a deployment' do
      expect(@director).to receive(:get).with('/deployments/foo/snapshots', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_snapshots('foo')
    end

    it 'lists snapshots for a job and index' do
      expect(@director).to receive(:get).with('/deployments/foo/jobs/bar/0/snapshots', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_snapshots('foo', 'bar', '0')
    end

    it 'deletes all snapshots of a deployment' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/deployments/foo/snapshots', {}).and_return(true)
      @director.delete_all_snapshots('foo')
    end

    it 'deletes snapshot' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/deployments/foo/snapshots/snap0a', {}).and_return(true)
      @director.delete_snapshot('foo', 'snap0a')
    end

    context 'when director returns 404' do
      let(:request_headers) { { 'Authorization' => 'Basic dXNlcjpwYXNz' } }
      before do
        stub_request(:get, 'https://127.0.0.1:8080/bad_endpoint').
          with(headers: request_headers).to_return(body: 'Not Found', status: 404)
      end
      let(:target_name) { 'FAKE-DIRECTOR' }
      before do
        status_response = { name: target_name }
        stub_request(:get, 'https://127.0.0.1:8080/info').
          with(headers: request_headers).
          to_return(body: JSON.generate(status_response), status: 200)
      end

      context 'when requesting tasks' do
        it 'raises error' do
          expect(@director).to receive(:get).
            with("/tasks/#{task_number}").
            and_return([404, 'Not Found'])
          expect {
            @director.get_task_state(task_number)
          }.to raise_error(Bosh::Cli::MissingTask)
        end
      end

      context 'when requesting anything else' do
        it 'should raise error suggesting director upgrade' do
          expect {
            @director.get('/bad_endpoint')
          }.to raise_error(Bosh::Cli::ResourceNotFound,
            "The #{target_name} bosh director doesn't understand the following " +
            "API call: /bad_endpoint. The bosh deployment may need to be upgraded."
          )
        end
      end
    end

    it 'escapes URL parameters' do
      expect(@director).to receive(:request_and_track).
        with(:delete, '/releases/fake-release-name?version=1%2Bdev.1', {}).and_return(true)
      @director.delete_release('fake-release-name', version: '1+dev.1')
    end
  end

  describe 'create_backup' do
    it 'tracks the backup task' do
      expect(@director).to receive(:request_and_track)
      .with(:post, '/backups', {})
      .and_return(true)
      @director.create_backup
    end
  end

  describe 'fetch_backup' do
    it 'fetches the backup file' do
      expect(@director).to receive(:get).with('/backups', nil, nil, {}, :file => true)
      .and_return([200, '/some/path', {}])
      expect(@director.fetch_backup).to eq('/some/path')
    end
  end

  describe 'list_locks' do
    it 'lists current locks' do
      locks = %w(fake-lock-1 fake-lock-2)
      expect(@director).to receive(:get).with('/locks', 'application/json').and_return([200, JSON.generate(locks)])
      expect(@director.list_locks).to eq(locks)
    end
  end

  describe 'checking status' do
    it 'considers target valid if it responds with 401 (for compatibility)' do
      allow(@director).to receive(:get).
        with('/info', 'application/json').
        and_return([401, 'Not authorized'])
      expect(@director.exists?).to eql(true)
    end

    it 'considers target valid if it responds with 200' do
      allow(@director).to receive(:get).
        with('/info', 'application/json').
        and_return([200, JSON.generate('name' => 'Director is your friend')])
      expect(@director.exists?).to eql(true)
    end
  end

  describe 'tracking request' do
    it 'starts polling task if request responded with a redirect (302) to task URL' do
      options = { :arg1 => 1, :arg2 => 2 }

      expect(@director).to receive(:request).
        with(:get, '/stuff', 'text/plain', 'abc').
        and_return([302, 'body', { :location => '/tasks/502' }])

      tracker = double('tracker', :track => 'polling result', :output => 'foo')

      expect(Bosh::Cli::TaskTracking::TaskTracker).to receive(:new).
        with(@director, '502', options).
        and_return(tracker)

      expect(@director.request_and_track(:get, '/stuff',
                                  { content_type: 'text/plain',
                                    payload: 'abc',
                                    arg1: 1, arg2: 2
                                  })).
        to eql(['polling result', '502'])
    end

    it 'starts polling task if request responded with a redirect (303) to task URL' do
      options = { :arg1 => 1, :arg2 => 2 }

      expect(@director).to receive(:request).
        with(:get, '/stuff', 'text/plain', 'abc').
        and_return([303, 'body', { :location => '/tasks/502' }])

      tracker = double('tracker', :track => 'polling result', :output => 'foo')

      expect(Bosh::Cli::TaskTracking::TaskTracker).to receive(:new).
        with(@director, '502', options).
        and_return(tracker)

      expect(@director.request_and_track(:get, '/stuff',
                                  { :content_type => 'text/plain',
                                    :payload      => 'abc',
                                    :arg1         => 1, :arg2 => 2
                                  })).
        to eql(['polling result', '502'])
    end

    describe 'not tracking trackable requests' do
      it 'returns without tracking/polling task if request responded with a redirect to task URL' do
        options = { :arg1 => 1, :arg2 => 2 }

        expect(URI).to receive(:parse).with(DUMMY_TARGET).and_call_original
        expect(Resolv).to receive(:getaddresses).with('target.example.com').and_return(['127.0.0.1'])
        @director = Bosh::Cli::Client::Director.new(DUMMY_TARGET, credentials, :no_track => true)

        expect(@director).to receive(:request).
          with(:get, '/stuff', 'text/plain', 'abc').
          and_return([302, 'body', { :location => '/tasks/502' }])

        tracker = double('tracker', :track => 'polling result', :output => 'foo')

        expect(Bosh::Cli::TaskTracking::TaskTracker).to receive(:new).
          with(@director, '502', options).
          never

        expect(@director.request_and_track(:get, '/stuff',
                                    { :content_type => 'text/plain',
                                      :payload      => 'abc',
                                      :arg1         => 1, :arg2 => 2
                                    })).
          to eql([:running, '502'])
      end
    end

    it 'considers all responses but 302 and 303 a failure' do
      [200, 404, 403].each do |code|
        expect(@director).to receive(:request).
          with(:get, '/stuff', 'text/plain', 'abc').
          and_return([code, 'body', {}])
        expect(@director.request_and_track(:get, '/stuff',
                                    { :content_type => 'text/plain',
                                      :payload      => 'abc',
                                      :arg1         => 1, :arg2 => 2
                                    })).to eql([:failed, nil])
      end
    end

    it 'reports task as non-trackable if its URL is unfamiliar' do
      expect(@director).to receive(:request).
        with(:get, '/stuff', 'text/plain', 'abc').
        and_return([302, 'body', { :location => '/track-task/502' }])
      expect(@director.request_and_track(:get, '/stuff',
                                  { :content_type => 'text/plain',
                                    :payload      => 'abc',
                                    :arg1         => 1, :arg2 => 2
                                  })).
        to eql([:non_trackable, nil])
    end

    it 'supports uploading with progress bar' do
      file = spec_asset('valid_release.tgz')
      f    = Bosh::Cli::FileWithProgressBar.open(file, 'r')

      allow(Bosh::Cli::FileWithProgressBar).to receive(:open).with(file, 'r').and_return(f)
      expect(@director).to receive(:request_and_track).
        with(:put, '/stuff', { :content_type => 'application/x-compressed',
                               :payload      => f })
      @director.upload_and_track(:put, '/stuff', file, :content_type => 'application/x-compressed')
      expect(f.progress_bar.finished?).to eql(true)
    end
  end

  describe 'performing HTTP requests' do
    it 'delegates to HTTPClient' do
      headers  = { 'Content-Type' => 'app/zb', 'a' => 'b', 'c' => 'd' }
      user     = 'user'
      password = 'pass'
      auth     = 'Basic ' + Base64.encode64("#{user}:#{password}").strip

      ssl_config = double('ssl_config')
      expect(ssl_config).to receive(:verify_mode=).
        with(OpenSSL::SSL::VERIFY_NONE)
      expect(ssl_config).to receive(:verify_callback=)

      client = double('httpclient', :ssl_config => ssl_config)
      expect(client).to receive(:send_timeout=).
        with(Bosh::Cli::Client::Director::API_TIMEOUT)
      expect(client).to receive(:receive_timeout=).
        with(Bosh::Cli::Client::Director::API_TIMEOUT)
      expect(client).to receive(:connect_timeout=).
        with(Bosh::Cli::Client::Director::CONNECT_TIMEOUT)

      allow(HTTPClient).to receive(:new).and_return(client)

      expect(client).to receive(:request).
        with(:get, 'http:///127.0.0.1:8080/stuff', :body => 'payload',
             :header                                     => headers.merge('Authorization' => auth))
      @director.send(:perform_http_request, :get,
                     'http:///127.0.0.1:8080/stuff', 'payload', headers)
    end
  end

  describe 'talking to REST API' do
    it 'performs HTTP request' do
      mock_response = double('response', :code => 200,
                             :body             => 'test', :headers => {})

      expect(@director).to receive(:perform_http_request).
        with(:get, 'https://127.0.0.1:8080/stuff', 'payload', 'h1' => 'a',
             'h2'                                                  => 'b', 'Content-Type' => 'app/zb').
        and_return(mock_response)

      expect(@director.send(:request, :get, '/stuff', 'app/zb', 'payload',
                     { 'h1' => 'a', 'h2' => 'b' })).
        to eql([200, 'test', {}])
    end

    it 'nicely wraps director error response' do
      [400, 403, 500].each do |code|
        expect {
          # Familiar JSON
          body = JSON.generate('code'        => '40422',
                               'description' => 'Weird stuff happened')

          mock_response = double('response',
                                 :code    => code,
                                 :body    => body,
                                 :headers => {})

          expect(@director).to receive(:perform_http_request).
            and_return(mock_response)
          @director.send(:request, :get, '/stuff', 'application/octet-stream',
                         'payload', { :hdr1 => 'a', :hdr2 => 'b' })
        }.to raise_error(Bosh::Cli::DirectorError,
                             'Error 40422: Weird stuff happened')

        expect {
          # Not JSON
          mock_response = double('response', :code => code,
                                 :body             => 'error message goes here',
                                 :headers          => {})
          expect(@director).to receive(:perform_http_request).
            and_return(mock_response)
          @director.send(:request, :get, '/stuff', 'application/octet-stream',
                         'payload', { :hdr1 => 'a', :hdr2 => 'b' })
        }.to raise_error(Bosh::Cli::DirectorError,
                             "HTTP #{code}: " +
                               'error message goes here')

        expect {
          # JSON but weird
          mock_response = double('response', :code => code,
                                 :body             => '{"c":"d","a":"b"}',
                                 :headers          => {})
          expect(@director).to receive(:perform_http_request).
            and_return(mock_response)
          @director.send(:request, :get, '/stuff', 'application/octet-stream',
                         'payload', { :hdr1 => 'a', :hdr2 => 'b' })
        }.to raise_error(Bosh::Cli::DirectorError,
                             "HTTP #{code}: " +
                               '{"c":"d","a":"b"}')
      end
    end

    it 'wraps file access exceptions' do
      expect(File).to receive(:open).and_raise(SystemCallError.new('err message', 22))

      expect {
        @director.send(:request, :get, '/stuff', 'app/zb', 'payload', {}, file: true)
      }.to raise_error(Bosh::Cli::DirectorError)
    end

    describe '#try_to_perform_http_request' do
      context 'when performing request fails with DirectorInaccessible error' do
        it 'retries the HTTP request the given number of times with given wait intervals' do
          expect(@director).
            to receive(:perform_http_request).
            exactly(3).times.
            and_raise(Bosh::Cli::DirectorInaccessible, 'fake-error')

          expect(@director).to receive(:sleep).with(2).exactly(2).times

          expect {
            @director.send(:try_to_perform_http_request, :get, '/stuff/app/zb', 'payload', {}, 3, 2)
          }.to raise_error(Bosh::Cli::DirectorInaccessible, /fake-error/)
        end
      end

      context 'when performing request fails with unknown error' do
        it 'does not retry the HTTP request' do
          error = Exception.new('fake-error')
          expect(@director).to receive(:perform_http_request).exactly(1).and_raise(error)

          expect {
            @director.send(:try_to_perform_http_request, :get, '/stuff/app/zb', 'payload', {}, 3, 2)
          }.to raise_error(error)
        end
      end
    end

    describe '#perform_http_request' do
      before { allow(HTTPClient).to receive(:new).and_return(http_client) }
      let(:http_client) { double('HTTPClient').as_null_object }

      [
        URI::Error.new('fake-error'),
        SocketError.new('fake-error'),
        Errno::ECONNREFUSED.new,
        Errno::ECONNRESET.new,
        Errno::ETIMEDOUT.new,
        Timeout::Error.new('fake-error'),
        HTTPClient::TimeoutError.new('fake-error'),
        HTTPClient::KeepAliveDisconnected.new('fake-error'),
        OpenSSL::SSL::SSLError.new('fake-error'),
      ].each do |error|
        context "when performing request fails with #{error} error" do
          it 'raises DirectorInaccessible error because director could not be reached' do
            expect(http_client).to receive(:request).and_raise(error)
            expect {
              @director.send(:perform_http_request, :get, '/stuff/app/zb', 'payload', {})
            }.to raise_error(Bosh::Cli::DirectorInaccessible)
          end
        end
      end

      context 'when director returns invalid http response' do
        it 'raises CliError error because there is nothing it can do' do
          expect(http_client).to receive(:request).and_raise(HTTPClient::BadResponseError, 'fake-error')
          expect {
            @director.send(:perform_http_request, :get, '/stuff/app/zb', 'payload', {})
          }.to raise_error(Bosh::Cli::CliError, /fake-error/)
        end
      end

      context 'when performing request fails with unknown error' do
        it 'raises CliError error' do
          expect(http_client).to receive(:request).and_raise(RuntimeError, 'fake-error')
          expect {
            @director.send(:perform_http_request, :get, '/stuff/app/zb', 'payload', {})
          }.to raise_error(Bosh::Cli::CliError, /fake-error/)
        end
      end
    end

    it 'streams file' do
      mock_response = double('response', :code => 200,
                             :body             => 'test body', :headers => {})
      expect(@director).to receive(:perform_http_request).
        and_yield('test body').and_return(mock_response)

      code, filename, headers =
        @director.send(:request, :get,
                       '/files/foo', nil, nil,
                       {}, { :file => true })

      expect(code).to eql(200)
      expect(File.read(filename)).to eql('test body')
      expect(headers).to eql({})
    end
  end
end

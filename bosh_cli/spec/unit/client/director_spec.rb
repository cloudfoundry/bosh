require 'spec_helper'

describe Bosh::Cli::Client::Director do

  DUMMY_TARGET = 'https://target.example.com:8080'

  before do
    URI.should_receive(:parse).with(DUMMY_TARGET).and_call_original
    Resolv.should_receive(:getaddresses).with('target.example.com').and_return(['127.0.0.1'])
    @director = Bosh::Cli::Client::Director.new(DUMMY_TARGET, 'user', 'pass')
    @director.stub(retry_wait_interval: 0)
  end

  describe 'checking availability' do
    it 'waits until director is ready' do
      @director.should_receive(:get_status).and_raise(Bosh::Cli::DirectorError)
      @director.should_receive(:get_status).and_return(cpi: 'aws')

      @director.wait_until_ready
    end
  end

  describe 'fetching status' do
    it 'tells if user is authenticated' do
      @director.should_receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate('user' => 'adam')])
      @director.authenticated?.should == true
    end

    it 'tells if user not authenticated' do
      @director.should_receive(:get).with('/info', 'application/json').
        and_return([403, 'Forbidden'])
      @director.authenticated?.should == false

      @director.should_receive(:get).with('/info', 'application/json').
        and_return([500, 'Error'])
      @director.authenticated?.should == false

      @director.should_receive(:get).with('/info', 'application/json').
        and_return([404, 'Not Found'])
      @director.authenticated?.should == false

      @director.should_receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate('user' => nil, 'version' => 1)])
      @director.authenticated?.should == false

      # Backward compatibility
      @director.should_receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate('status' => 'ZB')])
      @director.authenticated?.should == true
    end
  end

  describe 'interface REST API' do
    it 'has helper methods for HTTP verbs which delegate to generic request' do
      [:get, :put, :post, :delete].each do |verb|
        @director.should_receive(:request).with(verb, :arg1, :arg2)
        @director.send(verb, :arg1, :arg2)
      end
    end
  end

  describe 'API calls' do
    describe '#list_vms' do
      let(:http_client) { double('HTTPClient').as_null_object }
      let(:response) { double('Response', body: response_body, code: 200, headers: {}) }
      let(:request_headers) { { 'Content-Type' => 'application/json', 'Authorization' => 'Basic dXNlcjpwYXNz' } }

      before do
        HTTPClient.stub(new: http_client)
        http_client.stub(:request).with(:get, "https://127.0.0.1:8080/#{endpoint}", body: request_body, header: request_headers).and_return(response)
      end

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

      let(:response_body) do
        JSON.generate(vms)
      end

      let(:request_body) { nil }
      let(:endpoint) { 'deployments/foo/vms' }

      it 'lists vms for a given deployment' do
        expect(@director.list_vms('foo')).to eq vms
      end
    end

    it 'creates user' do
      @director.should_receive(:post).
        with('/users', 'application/json',
             JSON.generate('username' => 'joe', 'password' => 'pass')).
        and_return(true)
      @director.create_user('joe', 'pass')
    end

    it 'deletes users' do
      @director.should_receive(:delete).
        with('/users/joe').
        and_return([204, '', {}])
      @director.delete_user('joe').should == true
    end

    it 'fails to delete users' do
      @director.should_receive(:delete).
        with('/users/joe').
        and_return([500, '', {}])
      @director.delete_user('joe').should == false
    end

    it 'uploads local stemcell' do
      @director.should_receive(:upload_and_track).
        with(:post, '/stemcells', '/path',
             { :content_type => 'application/x-compressed' }).
        and_return(true)
      @director.upload_stemcell('/path')
    end

    it 'uploads remote stemcell' do
      @director.should_receive(:request_and_track).
        with(:post, '/stemcells',
             { :content_type => 'application/json',
               :payload      => JSON.generate('location' => 'stemcell_uri') }).
        and_return(true)
      @director.upload_remote_stemcell('stemcell_uri')
    end

    it 'lists stemcells' do
      @director.should_receive(:get).with('/stemcells', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_stemcells
    end

    it 'lists releases' do
      @director.should_receive(:get).with('/releases', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_releases
    end

    it 'lists deployments' do
      @director.should_receive(:get).with('/deployments', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_deployments
    end

    it 'lists currently running tasks (director version < 0.3.5)' do
      @director.should_receive(:get).with('/info', 'application/json').
        and_return([200, JSON.generate({ :version => '0.3.2' })])
      @director.should_receive(:get).
        with('/tasks?state=processing', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_running_tasks
    end

    it 'lists currently running tasks (director version >= 0.3.5)' do
      @director.should_receive(:get).
        with('/info', 'application/json').
        and_return([200, JSON.generate({ :version => '0.3.5' })])
      @director.should_receive(:get).
        with('/tasks?state=processing,cancelling,queued&verbose=1',
             'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_running_tasks
    end

    it 'lists recent tasks' do
      @director.should_receive(:get).
        with('/tasks?limit=30&verbose=1', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_recent_tasks

      @director.should_receive(:get).
        with('/tasks?limit=100000&verbose=1', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_recent_tasks(100000)

      @director.should_receive(:get).
        with('/tasks?limit=50&verbose=2', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_recent_tasks(50, 2)
    end

    it 'uploads local release' do
      @director.should_receive(:upload_and_track).
        with(:post, '/releases', '/path',
             { :content_type => 'application/x-compressed' }).
        and_return(true)
      @director.upload_release('/path')
    end

    it 'uploads local release (with rebase)' do
      @director.should_receive(:upload_and_track).
        with(:post, '/releases?rebase=true', '/path',
             { :content_type => 'application/x-compressed' }).
        and_return(true)
      @director.rebase_release('/path')
    end

    it 'uploads remote release' do
      @director.should_receive(:request_and_track).
        with(:post, '/releases',
             { :content_type => 'application/json',
               :payload      => JSON.generate('location' => 'release_uri') }).
        and_return(true)
      @director.upload_remote_release('release_uri')
    end

    it 'uploads remote release (with rebase)' do
      @director.should_receive(:request_and_track).
        with(:post, '/releases?rebase=true',
             { :content_type => 'application/json',
               :payload      => JSON.generate('location' => 'release_uri') }).
        and_return(true)
      @director.rebase_remote_release('release_uri')
    end

    it 'gets release info' do
      @director.should_receive(:get).
        with('/releases/foo', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.get_release('foo')
    end

    it 'gets deployment info' do
      @director.should_receive(:get).
        with('/deployments/foo', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.get_deployment('foo')
    end

    it 'deletes stemcell' do
      @director.should_receive(:request_and_track).
        with(:delete, '/stemcells/ubuntu/123', {}).and_return(true)
      @director.delete_stemcell('ubuntu', '123')
    end

    it 'deletes stemcell with force' do
      @director.should_receive(:request_and_track).
        with(:delete, '/stemcells/ubuntu/123?force=true', {}).and_return(true)
      @director.delete_stemcell('ubuntu', '123', :force => true)
    end

    it 'deletes deployment' do
      @director.should_receive(:request_and_track).
        with(:delete, '/deployments/foo', {}).and_return(true)
      @director.delete_deployment('foo')
    end

    it 'deletes release (non-force)' do
      @director.should_receive(:request_and_track).
        with(:delete, '/releases/za', {}).and_return(true)
      @director.delete_release('za')
    end

    it 'deletes release (force)' do
      @director.should_receive(:request_and_track).
        with(:delete, '/releases/zb?force=true', {}).and_return(true)
      @director.delete_release('zb', :force => true)
    end

    it 'deploys' do
      @director.should_receive(:request_and_track).
        with(:post, '/deployments',
             { :content_type => 'text/yaml', :payload => 'manifest' }).
        and_return(true)
      @director.deploy('manifest')
    end

    it 'changes job state' do
      @director.should_receive(:request_and_track).
        with(:put, '/deployments/foo/jobs/dea?state=stopped',
             { :content_type => 'text/yaml', :payload => 'manifest' }).
        and_return(true)
      @director.change_job_state('foo', 'manifest', 'dea', nil, 'stopped')
    end

    it 'changes job instance state' do
      @director.should_receive(:request_and_track).
        with(:put, '/deployments/foo/jobs/dea/0?state=detached',
             { :content_type => 'text/yaml', :payload => 'manifest' }).
        and_return(true)
      @director.change_job_state('foo', 'manifest', 'dea', 0, 'detached')
    end

    it 'changes job instance resurrection state' do
      @director.should_receive(:request).with(:put,
                                              '/deployments/foo/jobs/dea/0/resurrection',
                                              'application/json',
                                              '{"resurrection_paused":true}')
      @director.change_vm_resurrection('foo', 'dea', 0, true)
    end

    it 'change resurrection globally' do
      @director.should_receive(:request).with(:put,
                                              '/resurrection',
                                              'application/json',
                                              '{"resurrection_paused":false}')
      @director.change_vm_resurrection_for_all(false)
    end

    it 'gets task state' do
      @director.should_receive(:get).
        with('/tasks/232').
        and_return([200, JSON.generate({ 'state' => 'done' })])
      @director.get_task_state(232).should == 'done'
    end

    it 'whines on missing task' do
      @director.should_receive(:get).
        with('/tasks/232').
        and_return([404, 'Not Found'])
      lambda {
        @director.get_task_state(232).should
      }.should raise_error(Bosh::Cli::MissingTask)
    end

    it 'gets task output' do
      @director.should_receive(:get).
        with('/tasks/232/output', nil,
             nil, { 'Range' => 'bytes=42-' }).
        and_return([206, 'test', { :content_range => 'bytes 42-56/100' }])
      @director.get_task_output(232, 42).should == ['test', 57]
    end

    it "doesn't set task output body and new offset if there's a byte range unsatisfiable response" do
      @director.should_receive(:get).
        with('/tasks/232/output', nil,
             nil, { 'Range' => 'bytes=42-' }).
        and_return([416, 'Byte range unsatisfiable', { :content_range => 'bytes */100' }])
      @director.get_task_output(232, 42).should == [nil, nil]
    end

    it "doesn't set task output new offset if it wasn't a partial response" do
      @director.should_receive(:get).
        with('/tasks/232/output', nil, nil,
             { 'Range' => 'bytes=42-' }).
        and_return([200, 'test'])
      @director.get_task_output(232, 42).should == ['test', nil]
    end

    it 'know how to find time difference with director' do
      now         = Time.now
      server_time = now - 100
      Time.stub(:now).and_return(now)

      @director.should_receive(:get).with('/info').
        and_return([200, JSON.generate('version' => 1),
                    { :date => server_time.rfc822 }])
      @director.get_time_difference.to_i.should == 100
    end

    it 'takes snapshot for a deployment' do
      @director.should_receive(:request_and_track).
        with(:post, '/deployments/foo/snapshots', {}).
        and_return(true)
      @director.take_snapshot('foo')
    end

    it 'takes snapshot for a job and index' do
      @director.should_receive(:request_and_track).
        with(:post, '/deployments/foo/jobs/bar/0/snapshots', {}).
        and_return(true)
      @director.take_snapshot('foo', 'bar', '0')
    end

    it 'lists snapshots for a deployment' do
      @director.should_receive(:get).with('/deployments/foo/snapshots', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_snapshots('foo')
    end

    it 'lists snapshots for a job and index' do
      @director.should_receive(:get).with('/deployments/foo/jobs/bar/0/snapshots', 'application/json').
        and_return([200, JSON.generate([]), {}])
      @director.list_snapshots('foo', 'bar', '0')
    end

    it 'deletes all snapshots of a deployment' do
      @director.should_receive(:request_and_track).
        with(:delete, '/deployments/foo/snapshots', {}).and_return(true)
      @director.delete_all_snapshots('foo')
    end

    it 'deletes snapshot' do
      @director.should_receive(:request_and_track).
        with(:delete, '/deployments/foo/snapshots/snap0a', {}).and_return(true)
      @director.delete_snapshot('foo', 'snap0a')
    end
  end

  describe 'create_backup' do
    it 'tracks the backup task' do
      @director.should_receive(:request_and_track)
      .with(:post, '/backups', {})
      .and_return(true)
      @director.create_backup
    end
  end

  describe 'fetch_backup' do
    it 'fetches the backup file' do
      @director.should_receive(:get).with('/backups', nil, nil, {}, :file => true)
      .and_return([200, '/some/path', {}])
      expect(@director.fetch_backup).to eq('/some/path')
    end
  end

  describe 'checking status' do
    it 'considers target valid if it responds with 401 (for compatibility)' do
      @director.stub(:get).
        with('/info', 'application/json').
        and_return([401, 'Not authorized'])
      @director.exists?.should be(true)
    end

    it 'considers target valid if it responds with 200' do
      @director.stub(:get).
        with('/info', 'application/json').
        and_return([200, JSON.generate('name' => 'Director is your friend')])
      @director.exists?.should be(true)
    end
  end

  describe 'tracking request' do
    it 'starts polling task if request responded with a redirect (302) to task URL' do
      options = { :arg1 => 1, :arg2 => 2 }

      @director.should_receive(:request).
        with(:get, '/stuff', 'text/plain', 'abc').
        and_return([302, 'body', { :location => '/tasks/502' }])

      tracker = double('tracker', :track => 'polling result', :output => 'foo')

      Bosh::Cli::TaskTracking::TaskTracker.should_receive(:new).
        with(@director, '502', options).
        and_return(tracker)

      @director.request_and_track(:get, '/stuff',
                                  { :content_type => 'text/plain',
                                    :payload      => 'abc',
                                    :arg1         => 1, :arg2 => 2
                                  }).
        should == ['polling result', '502']
    end

    it 'starts polling task if request responded with a redirect (303) to task URL' do
      options = { :arg1 => 1, :arg2 => 2 }

      @director.should_receive(:request).
        with(:get, '/stuff', 'text/plain', 'abc').
        and_return([303, 'body', { :location => '/tasks/502' }])

      tracker = double('tracker', :track => 'polling result', :output => 'foo')

      Bosh::Cli::TaskTracking::TaskTracker.should_receive(:new).
        with(@director, '502', options).
        and_return(tracker)

      @director.request_and_track(:get, '/stuff',
                                  { :content_type => 'text/plain',
                                    :payload      => 'abc',
                                    :arg1         => 1, :arg2 => 2
                                  }).
        should == ['polling result', '502']
    end

    describe 'not tracking trackable requests' do
      it 'returns without tracking/polling task if request responded with a redirect to task URL' do
        options = { :arg1 => 1, :arg2 => 2 }

        URI.should_receive(:parse).with(DUMMY_TARGET).and_call_original
        Resolv.should_receive(:getaddresses).with('target.example.com').and_return(['127.0.0.1'])
        @director = Bosh::Cli::Client::Director.new(DUMMY_TARGET, 'user', 'pass', :no_track => true)

        @director.should_receive(:request).
          with(:get, '/stuff', 'text/plain', 'abc').
          and_return([302, 'body', { :location => '/tasks/502' }])

        tracker = double('tracker', :track => 'polling result', :output => 'foo')

        Bosh::Cli::TaskTracking::TaskTracker.should_receive(:new).
          with(@director, '502', options).
          never

        @director.request_and_track(:get, '/stuff',
                                    { :content_type => 'text/plain',
                                      :payload      => 'abc',
                                      :arg1         => 1, :arg2 => 2
                                    }).
          should == [:running, '502']
      end
    end

    it 'considers all responses but 302 and 303 a failure' do
      [200, 404, 403].each do |code|
        @director.should_receive(:request).
          with(:get, '/stuff', 'text/plain', 'abc').
          and_return([code, 'body', {}])
        @director.request_and_track(:get, '/stuff',
                                    { :content_type => 'text/plain',
                                      :payload      => 'abc',
                                      :arg1         => 1, :arg2 => 2
                                    }).
          should == [:failed, nil]
      end
    end

    it 'reports task as non-trackable if its URL is unfamiliar' do
      @director.should_receive(:request).
        with(:get, '/stuff', 'text/plain', 'abc').
        and_return([302, 'body', { :location => '/track-task/502' }])
      @director.request_and_track(:get, '/stuff',
                                  { :content_type => 'text/plain',
                                    :payload      => 'abc',
                                    :arg1         => 1, :arg2 => 2
                                  }).
        should == [:non_trackable, nil]
    end

    it 'supports uploading with progress bar' do
      file = spec_asset('valid_release.tgz')
      f    = Bosh::Cli::FileWithProgressBar.open(file, 'r')

      Bosh::Cli::FileWithProgressBar.stub(:open).with(file, 'r').and_return(f)
      @director.should_receive(:request_and_track).
        with(:put, '/stuff', { :content_type => 'application/x-compressed',
                               :payload      => f })
      @director.upload_and_track(:put, '/stuff', file,
                                 :content_type => 'application/x-compressed')
      f.progress_bar.finished?.should be(true)
    end
  end

  describe 'performing HTTP requests' do
    it 'delegates to HTTPClient' do
      headers  = { 'Content-Type' => 'app/zb', 'a' => 'b', 'c' => 'd' }
      user     = 'user'
      password = 'pass'
      auth     = 'Basic ' + Base64.encode64("#{user}:#{password}").strip

      ssl_config = double('ssl_config')
      ssl_config.should_receive(:verify_mode=).
        with(OpenSSL::SSL::VERIFY_NONE)
      ssl_config.should_receive(:verify_callback=)

      client = double('httpclient', :ssl_config => ssl_config)
      client.should_receive(:send_timeout=).
        with(Bosh::Cli::Client::Director::API_TIMEOUT)
      client.should_receive(:receive_timeout=).
        with(Bosh::Cli::Client::Director::API_TIMEOUT)
      client.should_receive(:connect_timeout=).
        with(Bosh::Cli::Client::Director::CONNECT_TIMEOUT)

      HTTPClient.stub(:new).and_return(client)

      client.should_receive(:request).
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

      @director.should_receive(:perform_http_request).
        with(:get, 'https://127.0.0.1:8080/stuff', 'payload', 'h1' => 'a',
             'h2'                                                  => 'b', 'Content-Type' => 'app/zb').
        and_return(mock_response)

      @director.send(:request, :get, '/stuff', 'app/zb', 'payload',
                     { 'h1' => 'a', 'h2' => 'b' }).
        should == [200, 'test', {}]
    end

    it 'nicely wraps director error response' do
      [400, 403, 500].each do |code|
        lambda {
          # Familiar JSON
          body = JSON.generate('code'        => '40422',
                               'description' => 'Weird stuff happened')

          mock_response = double('response',
                                 :code    => code,
                                 :body    => body,
                                 :headers => {})

          @director.should_receive(:perform_http_request).
            and_return(mock_response)
          @director.send(:request, :get, '/stuff', 'application/octet-stream',
                         'payload', { :hdr1 => 'a', :hdr2 => 'b' })
        }.should raise_error(Bosh::Cli::DirectorError,
                             'Error 40422: Weird stuff happened')

        lambda {
          # Not JSON
          mock_response = double('response', :code => code,
                                 :body             => 'error message goes here',
                                 :headers          => {})
          @director.should_receive(:perform_http_request).
            and_return(mock_response)
          @director.send(:request, :get, '/stuff', 'application/octet-stream',
                         'payload', { :hdr1 => 'a', :hdr2 => 'b' })
        }.should raise_error(Bosh::Cli::DirectorError,
                             "HTTP #{code}: " +
                               'error message goes here')

        lambda {
          # JSON but weird
          mock_response = double('response', :code => code,
                                 :body             => '{"c":"d","a":"b"}',
                                 :headers          => {})
          @director.should_receive(:perform_http_request).
            and_return(mock_response)
          @director.send(:request, :get, '/stuff', 'application/octet-stream',
                         'payload', { :hdr1 => 'a', :hdr2 => 'b' })
        }.should raise_error(Bosh::Cli::DirectorError,
                             "HTTP #{code}: " +
                               '{"c":"d","a":"b"}')
      end
    end

    it 'wraps director access exceptions' do
      @director.stub(num_retries: 1)
      [URI::Error, SocketError, Errno::ECONNREFUSED].each do |err|
        @director.should_receive(:perform_http_request).
          and_raise(err.new('err message'))
        lambda {
          @director.send(:request, :get, '/stuff', 'app/zb', 'payload', {})
        }.should raise_error(Bosh::Cli::DirectorInaccessible)
      end

      @director.should_receive(:perform_http_request).
        and_raise(SystemCallError.new('err message', 22))

      lambda {
        @director.send(:request, :get, '/stuff', 'app/zb', 'payload', {})
      }.should raise_error Bosh::Cli::DirectorError
    end

    it 'retries the HTTP request the given number of times with given wait intervals' do
      @director.should_receive(:perform_http_request).exactly(3).times.and_raise(URI::Error)
      @director.should_receive(:sleep).with(2).exactly(2).times

      expect {
        @director.send(:try_to_perform_http_request, :get, '/stuff/app/zb', 'payload', {}, 3, 2)
      }.to raise_error(Bosh::Cli::DirectorInaccessible)
    end

    it 'streams file' do
      mock_response = double('response', :code => 200,
                             :body             => 'test body', :headers => {})
      @director.should_receive(:perform_http_request).
        and_yield('test body').and_return(mock_response)

      code, filename, headers =
        @director.send(:request, :get,
                       '/files/foo', nil, nil,
                       {}, { :file => true })

      code.should == 200
      File.read(filename).should == 'test body'
      headers.should == {}
    end
  end

end

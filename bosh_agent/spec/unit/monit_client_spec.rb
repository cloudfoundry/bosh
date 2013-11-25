require 'spec_helper'

module Bosh::Agent
  describe MonitClient do
    STATUS = Crack::XML.parse(File.read(File.expand_path("../../assets/monit_status.xml", __FILE__)))

    describe "get_status" do
      it "should connect to the monit HTTP interface with auth" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")
        response.stub(:body).and_return(File.read(File.expand_path("../../assets/monit_status.xml", __FILE__)))

        http_client.should_receive(:request) { |request|
          request["authorization"].should be_nil
        }.and_return(response)

        client = MonitClient.new("http://localhost:123")
        client.send(:get_status)
      end

      it "should connect to the monit HTTP interface protected by basic auth" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")
        response.stub(:body).and_return(File.read(File.expand_path("../../assets/monit_status.xml", __FILE__)))

        http_client.should_receive(:request) { |request|
          request["authorization"].should == "Basic dXNlcjpwYXNzd29yZA=="
        }.and_return(response)

        client = MonitClient.new("http://user:password@localhost:123")
        client.send(:get_status)
      end

      it "should request the status xml" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")
        response.stub(:body).and_return(File.read(File.expand_path("../../assets/monit_status.xml", __FILE__)))

        http_client.should_receive(:request) { |request|
          request.method.should == "GET"
          request.path.should == "/_status2?format=xml"
        }.and_return(response)

        client = MonitClient.new("http://localhost:123")
        status = client.send(:get_status)
        status.should be_a_kind_of(Hash)
        status["monit"]["services"]["service"].should_not be_nil
        status["monit"]["servicegroups"]["servicegroup"].should_not be_nil
      end

      it "should not fail on empty servicegroups" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")
        response.stub(:body).and_return(File.read(File.expand_path("../../assets/monit_status_without_servicegroups.xml", __FILE__)))

        http_client.should_receive(:request) { |request|
          request.method.should == "GET"
          request.path.should == "/_status2?format=xml"
        }.and_return(response)

        client = MonitClient.new("http://localhost:123")
        status = client.send(:get_status)
        status["monit"]["servicegroups"].should be_nil
      end

      it "should fail when monit returns an error" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("404")
        response.stub(:message).and_return("Not Found")

        http_client.should_receive(:request).and_return(response)

        client = MonitClient.new("http://localhost:123")
        lambda { client.send(:get_status) }.should raise_error("Not Found")
      end
    end

    describe "monit_info" do
      it "should return id, incarnation, and version" do
        client = MonitClient.new("http://localhost:123")
        client.stub(:get_status).and_return(STATUS)
        client.monit_info.should ==  {
          :id=>"946bd13e5c851e91698f1160754ef1a0",
          :incarnation=>"1299869457",
          :version=>"5.2.1"
        }
      end
    end

    describe "get_services" do
      it "should select all services" do
        client = MonitClient.new("http://localhost:123")
        services = client.send(:get_services, STATUS, :all => true)
        services.collect { |service| service["name"] }.should == ["apache", "httpd.conf", "mysql", "system_test.local"]
      end

      it "should select services by group" do
        client = MonitClient.new("http://localhost:123")
        services = client.send(:get_services, STATUS, :group => "www")
        services.collect { |service| service["name"] }.should == ["apache", "httpd.conf", "mysql"]
      end

      it "should select services by type" do
        client = MonitClient.new("http://localhost:123")
        services = client.send(:get_services, STATUS, :type => :system)
        services.collect { |service| service["name"] }.should == ["system_test.local"]
      end

      it "should select services by multiple selectors" do
        client = MonitClient.new("http://localhost:123")
        services = client.send(:get_services, STATUS, :group => "www", :type => :process)
        services.collect { |service| service["name"] }.should == ["apache", "mysql"]
      end

      it "should select services by name" do
        client = MonitClient.new("http://localhost:123")
        services = client.send(:get_services, STATUS, "apache")
        services.collect { |service| service["name"] }.should == ["apache"]
      end

      it "should return nothing if the requested service name doesn't exist" do
        client = MonitClient.new("http://localhost:123")
        services = client.send(:get_services, STATUS, "apache-bad")
        services.collect { |service| service["name"] }.should == []
      end
    end

    describe "service_action" do
      it "should connect to the monit HTTP interface" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")

        http_client.should_receive(:request) { |request|
          request["authorization"].should be_nil
        }.and_return(response)

        client = MonitClient.new("http://localhost:123")
        client.send(:service_action, "test", "start")
      end

      it "should connect to the monit HTTP interface protected by basic auth" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")

        http_client.should_receive(:request) { |request|
          request["authorization"].should == "Basic dXNlcjpwYXNzd29yZA=="
        }.and_return(response)

        client = MonitClient.new("http://user:password@localhost:123")
        client.send(:service_action, "test", "start")
      end

      it "should send action to the right endpoint" do
        http_client = double("http_client")
        Net::HTTP.should_receive(:new).with("localhost", 123).and_return(http_client)

        response = double("response")
        response.stub(:code).and_return("200")

        http_client.should_receive(:request) { |request|
          request.method.should == "POST"
          request.path.should == "/test"
          request["content-type"].should == "application/x-www-form-urlencoded"
          request.body.should == "action=testaction"
        }.and_return(response)

        client = MonitClient.new("http://user:password@localhost:123")
        client.send(:service_action, "test", "testaction")
      end

    end

    describe "status" do
      it "should return basic status" do
        client = MonitClient.new("http://localhost:123")
        client.stub(:get_status).and_return(STATUS)
        status = client.status(:group => "www")

        status["apache"][:status].should == {:message => "running", :code => 0}
        status["apache"][:monitor].should == :yes
        status["apache"][:type].should == :process
        status["apache"][:raw].should == STATUS["monit"]["services"]["service"][0]

        status["mysql"][:status].should == {:message => "process is not running", :code => 512}
        status["mysql"][:monitor].should == :yes
        status["mysql"][:type].should == :process

        status["httpd.conf"][:status].should == {:message => "file doesn't exist", :code => 512}
        status["httpd.conf"][:monitor].should == :yes
        status["httpd.conf"][:type].should == :file
      end
    end

    describe "actions" do
      [:start, :stop, :restart, :monitor, :unmonitor].each do |action|
        it "should support #{action}" do
          client = MonitClient.new("http://localhost:123")
          client.stub(:get_status).and_return(STATUS)
          client.should_receive(:service_action).with("apache", action.to_s)
          client.send(action, "apache")
        end
      end
    end
  end
end

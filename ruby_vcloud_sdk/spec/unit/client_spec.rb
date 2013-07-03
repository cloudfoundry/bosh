require "spec_helper"
require_relative "client_response"
require "stringio"
require "logger"
require "nokogiri/diff"

module VCloudSdk
  vcd = VCloudSdk::Test::vcd_settings
  logger = Config.logger

  Config.configure({"logger" => logger,
    "rest_logger" =>VCloudSdk::Test::rest_logger(logger),
    "rest_throttle" => vcd["control"]["rest_throttle"]})

  describe Client, :min, :all do
    let(:url) { vcd["url"] }
    let(:username) { vcd["user"] }
    let(:password) { vcd["password"] }
    let(:control) { vcd["control"] }
    let(:entities) { vcd["entities"] }
    let(:auth_cookies) { {"vcloud-token" => vcd["testing"]["cookies"]} }

    def mock_rest_connection
      @upload_file_state = "success"
      current_vapp_state = "nothing"
      finalize_vapp_task_state = "running"
      delete_vapp_template_task_state = "running"
      delete_vapp_task_state = "running"
      change_vm_task_state = "running"
      catalog_state = "not_added"
      template_instantiate_state = "running"
      vapp_power_state = "off"
      existing_media_state = "busy"
      metadata_value = ""
      metadata_xml = ""
      rest_client = mock("Rest Client")
      response_mapping = {
          :get => {
              Test::Response::ADMIN_VCLOUD_LINK => lambda {
                |url, headers| Test::Response::VCLOUD_RESPONSE },
              Test::Response::ADMIN_ORG_LINK => lambda {
                |url, headers| Test::Response::ADMIN_ORG_RESPONSE },
              Test::Response::VDC_LINK => lambda {
                |url, headers| Test::Response::VDC_RESPONSE },
              Test::Response::CATALOG_LINK => lambda { |url, headers|
                case (catalog_state)
                  when "not_added"
                    Test::Response::CATALOG_RESPONSE
                  when "added"
                    Test::Response::CATALOG_ITEM_ADDED_RESPONSE
                end
              },
              Test::Response::CATALOG_ITEM_VAPP_LINK => lambda {
                |url, headers| Test::Response::CATALOG_ADD_ITEM_RESPONSE
              },
              Test::Response::VAPP_TEMPLATE_LINK => lambda { |url, headers|
                case (current_vapp_state)
                  when "ovf_uploaded"
                    Test::Response::VAPP_TEMPLATE_NO_DISKS_RESPONSE
                  when "nothing"
                    Test::Response::VAPP_TEMPLATE_UPLOAD_OVF_WAITING_RESPONSE
                  when "disks_uploaded"
                    Test::Response::VAPP_TEMPLATE_UPLOAD_COMPLETE
                  when "disks_upload_failed"
                    Test::Response::VAPP_TEMPLATE_UPLOAD_FAILED
                  when "finalized"
                    Test::Response::VAPP_TEMPLATE_READY_RESPONSE
                end
              },
              Test::Response::FINALIZE_UPLOAD_TASK_LINK => lambda {
                  |url, headers|
                case (finalize_vapp_task_state)
                  when "running"
                    finalize_vapp_task_state = "success"
                    current_vapp_state = "finalized"
                    Test::Response::FINALIZE_UPLOAD_TASK_RESPONSE
                  when "success"
                    Test::Response::FINALIZE_UPLOAD_TASK_DONE_RESPONSE
                end
              },
              Test::Response::VAPP_TEMPLATE_DELETE_TASK_LINK => lambda {
                  |url, headers|
                case (delete_vapp_template_task_state)
                  when "running"
                    delete_vapp_template_task_state = "success"
                    Test::Response::VAPP_TEMPLATE_DELETE_RUNNING_TASK
                  when "success"
                    Test::Response::VAPP_TEMPLATE_DELETE_DONE_TASK
                end
              },
              Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_LINK =>
                lambda { |url, headers|
                  Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_ITEM_RESPONSE
                },
              Test::Response::EXISTING_VAPP_TEMPLATE_LINK => lambda {
                  |url, headers|
                Test::Response::EXISTING_VAPP_TEMPLATE_READY_RESPONSE
              },
              Test::Response::EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_LINK =>
                lambda { |url, headers|
                  case (template_instantiate_state)
                    when "running"
                      template_instantiate_state = "success"
                      Test::Response::
                        EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_START_RESPONSE
                    when "success"
                      Test::Response::
                      EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_SUCCESS_RESPONSE
                  end
                },
              Test::Response::INSTANTIATED_VAPP_LINK => lambda {
                  |url, headers|
                case(vapp_power_state)
                  when "off"
                    Test::Response::INSTANTIAED_VAPP_RESPONSE
                   when "on"
                    Test::Response::INSTANTIAED_VAPP_ON_RESPONSE
                  when "powered-off"
                    Test::Response::INSTANTIAED_VAPP_POWERED_OFF_RESPONSE
                  when "suspended"
                    Test::Response::INSTANTIATED_SUSPENDED_VAPP_RESPONSE
                end
              },
              Test::Response::INSTANTIATED_VAPP_DELETE_TASK_LINK => lambda {
                  |url, headers|
                case (delete_vapp_task_state)
                  when "running"
                    delete_vapp_task_state = "success"
                    Test::Response::INSTANTIATED_VAPP_DELETE_RUNNING_TASK
                  when "success"
                    Test::Response::INSTANTIATED_VAPP_DELETE_DONE_TASK
                end
              },
              Test::Response::INSTANTIATED_VM_LINK => lambda { |url, headers|
                Test::Response::INSTANTIATED_VM_RESPONSE
              },
              Test::Response::INSTANTIATED_VM_CPU_LINK => lambda {
                |url, headers| Test::Response::INSTANTIATED_VM_CPU_RESPONSE
              },
              Test::Response::INSTANTIATED_VM_MEMORY_LINK => lambda {
                |url, headers| Test::Response::INSTANTIATED_VM_MEMORY_RESPONSE
              },
              Test::Response::INSTANTIATED_VM_MODIFY_TASK_LINK => lambda {
                  |url, headers|
                case(change_vm_task_state)
                  when "running"
                    change_vm_task_state = "success"
                    Test::Response::INSTANTIATED_VM_MODIFY_TASK_RUNNING
                  when "success"
                    Test::Response::INSTANTIATED_VM_MODIFY_TASK_SUCCESS
                end
              },
              Test::Response::EXISTING_VAPP_LINK => lambda { |url, headers|
                Test::Response::INSTANTIAED_VAPP_RESPONSE
              },
              Test::Response::INSTANTIATED_VAPP_POWER_ON_TASK_LINK => lambda {
                  |url, headers|
                Test::Response::INSTANTED_VAPP_POWER_TASK_SUCCESS
              },
              Test::Response::ORG_NETWORK_LINK => lambda { |url, headers|
                Test::Response::ORG_NETWORK_RESPONSE
              },
              Test::Response::INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK =>
                  lambda { |url, headers|
                Test::Response::
                  INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_RESPONSE
              },
              Test::Response::
                INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_TASK_LINK =>
                  lambda { |url, headers|
                    Test::Response::
                  INSTANTIATED_VAPP_NETWORK_CONFIG_MODIFY_NETWORK_TASK_SUCCESS
                  },
              Test::Response::INSTANTIATED_VM_NETWORK_SECTION_LINK => lambda {
                  |url, headers|
                Test::Response::INSTANTIATED_VM_NETWORK_SECTION_RESPONSE
              },
              Test::Response::MEDIA_LINK => lambda { |url, headers|
                Test::Response::MEDIA_UPLOAD_PENDING_RESPONSE
              },
              Test::Response::EXISTING_MEDIA_CATALOG_ITEM_LINK  => lambda {
                |url, headers| Test::Response::EXISTING_MEDIA_CATALOG_ITEM
              },
              Test::Response::EXISTING_MEDIA_LINK  => lambda { |url, headers|
                case(existing_media_state)
                  when "busy"
                    existing_media_state = "done"
                    Test::Response::EXISTING_MEDIA_BUSY_RESPONSE
                  when "done"
                    Test::Response::EXISTING_MEDIA_DONE_RESPONSE
                end
              },
              Test::Response::METADATA_SET_LINK => lambda { |url, headers|
                metadata_xml
              },
              Test::Response::INDY_DISK_URL => lambda { |url, headers|
                Test::Response::INDY_DISK_RESPONSE
              },
              Test::Response::EXISTING_VAPP_RESOLVER_URL => lambda {
                |url,headers| Test::Response::EXISTING_VAPP_RESOLVER_RESPONSE
              },
              Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_URL =>
                  lambda { |url,headers|
                Test::Response::
                  EXISTING_VAPP_TEMPLATE_CATALOG_RESOLVER_RESPONSE
              },
              Test::Response::VAPP_TEMPLATE_CATALOG_RESOLVER_URL => lambda {
                  |url,headers|
                Test::Response::VAPP_TEMPLATE_CATALOG_RESOLVER_RESPONSE
              }
          },
          :post => {
              Test::Response::LOGIN_LINK => lambda { |url, data, headers|
                session_object = Test::Response::SESSION

                def session_object.cookies
                  {"vcloud-token" =>
                    VCloudSdk::Test::vcd_settings["testing"]["cookies"]}
                end

                session_object
              },
              Test::Response::VDC_VAPP_UPLOAD_LINK => lambda {
                  |url, data, headers|
                current_vapp_state = "nothing"
                Test::Response::VAPP_TEMPLATE_UPLOAD_OVF_WAITING_RESPONSE
              },
              Test::Response::CATALOG_ADD_ITEM_LINK => lambda {
                  |url, data, headers|
                case(Xml::WrapperFactory.wrap_document(data))
                  when Xml::WrapperFactory.wrap_document(
                      Test::Response::CATALOG_ADD_VAPP_REQUEST)
                    catalog_state = "added"
                    Test::Response::CATALOG_ADD_ITEM_RESPONSE
                   when Xml::WrapperFactory.wrap_document(
                      Test::Response::MEDIA_ADD_TO_CATALOG_REQUEST)
                    catalog_state = "added"
                    Test::Response::MEDIA_ADD_TO_CATALOG_RESPONSE
                  else
                    Config.logger.error("Response mapping not found for " +
                                        "POST and #{url} and #{data}")
                    raise "Response mapping not found."
                end
              },
              Test::Response::VAPP_TEMPLATE_INSTANTIATE_LINK => lambda {
                  |url, data, headers|
                Test::Response::EXISTING_VAPP_TEMPLATE_INSTANTIATE_RESPONSE
              },
              Test::Response::RECONFIGURE_VM_LINK => lambda {
                  |url, data, headers|
                Test::Response::RECONFIGURE_VM_TASK
              },
              Test::Response::INSTANTIATED_VAPP_POWER_ON_LINK => lambda {
                  |url, data, headers|
                vapp_power_state = "on"
                Test::Response::INSTANTED_VAPP_POWER_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VAPP_POWER_OFF_LINK => lambda {
                  |url, data, headers|
                vapp_power_state = "powered-off"
                Test::Response::INSTANTED_VAPP_POWER_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VAPP_POWER_REBOOT_LINK => lambda {
                  |url, data, headers|
                vapp_power_state = "on"
                Test::Response::INSTANTED_VAPP_POWER_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VAPP_UNDEPLOY_LINK => lambda {
                  |url, data, headers|
                vapp_power_state = "off"
                Test::Response::INSTANTED_VAPP_POWER_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VAPP_DISCARD_STATE_LINK => lambda {
                  |url, data, headers|
                vapp_power_state = "off"
                Test::Response::INSTANTED_VAPP_POWER_TASK_RUNNING
              },
              Test::Response::MEDIA_UPLOAD_LINK => lambda {
                  |url, data, headers|
                Test::Response::MEDIA_UPLOAD_PENDING_RESPONSE
              },
              Test::Response::INSTANTIATED_VM_INSERT_MEDIA_LINK => lambda {
                  |url, data, headers|
                Test::Response::INSTANTIATED_VM_INSERT_MEDIA_TASK_DONE
              },
              Test::Response::VDC_INDY_DISKS_LINK => lambda {
                  |url, data, headers|
                Test::Response::INDY_DISK_CREATE_RESPONSE
              },
              Test::Response::INSTANTIATED_VM_ATTACH_DISK_LINK => lambda {
                  |url, data, headers|
                Test::Response::INDY_DISK_ATTACH_TASK
              }
          },
          :put => {
              Test::Response::VAPP_TEMPLATE_UPLOAD_OVF_LINK => lambda {
                  |url, data, headers|
                current_vapp_state = "ovf_uploaded"
                ""
              },
               Test::Response::INSTANTIATED_VM_CPU_LINK => lambda {
                  |url, data, headers|
                change_vm_task_state = "running"
                Test::Response::INSTANTIATED_VM_MODIFY_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VM_MEMORY_LINK => lambda {
                  |url, data, headers|
                change_vm_task_state = "running"
                Test::Response::INSTANTIATED_VM_MODIFY_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VM_LINK => lambda {
                  |url, data, headers|
                change_vm_task_state = "running"
                Test::Response::INSTANTIATED_VM_MODIFY_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VM_HARDWARE_SECTION_LINK =>
                  lambda { |url, data, headers|
                change_vm_task_state = "running"
                Test::Response::INSTANTIATED_VM_MODIFY_TASK_RUNNING
              },
              Test::Response::INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK =>
                  lambda { |url, data, headers|
                Test::Response::
                  INSTANTIATED_VAPP_NETWORK_CONFIG_MODIFY_NETWORK_TASK_SUCCESS
              },
              Test::Response::INSTANTIATED_VM_NETWORK_SECTION_LINK => lambda {
                  |url, data, headers|
                change_vm_task_state = "running"
                Test::Response::INSTANTIATED_VM_MODIFY_TASK_RUNNING
              },
              Test::Response::METADATA_SET_LINK => lambda {
                  |url, data, headers|
                received =  Xml::WrapperFactory.wrap_document(data)
                metadata_value = received.value
                metadata_xml = data
                Test::Response::METADATA_SET_TASK_DONE
              }
          },
          :delete => {
              Test::Response::VAPP_TEMPLATE_LINK => lambda { |url, headers|
                Test::Response::VAPP_TEMPLATE_DELETE_RUNNING_TASK
              },
              Test::Response::INSTANTIATED_VAPP_LINK => lambda {
                  |url, headers|
                Test::Response::INSTANTIATED_VAPP_DELETE_RUNNING_TASK
              },
              Test::Response::CATALOG_ITEM_VAPP_LINK => lambda {
                  |url, headers|
                nil
              },
              Test::Response::EXISTING_MEDIA_LINK => lambda { |url, headers|
                Test::Response::EXISTING_MEDIA_DELETE_TASK_DONE
              },
              Test::Response::EXISTING_MEDIA_CATALOG_ITEM_LINK => lambda {
                  |url, headers|
                nil
              },
              Test::Response::MEDIA_LINK => lambda { |url, headers|
                Test::Response::MEDIA_DELETE_TASK_DONE
              },
              Test::Response::INDY_DISK_URL => lambda { |url, headers|
                Test::Response::INDY_DISK_DELETE_TASK
              },
          }
      }

      #Working around Ruby 1.8"s lack of define_singleton_method
      metaclass = class << response_mapping;
        self;
      end

      metaclass.send :define_method, :get_mapping do |http_method, url|
        mapping = self[http_method][url]
        if mapping.nil?
          Config.logger.error("Response mapping not found for " +
            "#{http_method} and #{url}")
          # string substitution doesn"t work here for some reason
          raise "Response mapping not found."
        else
          mapping
        end
      end

      rest_client.stub(:get) do |headers|
        response_mapping.get_mapping(:get, build_url).call(build_url, headers)
      end
      rest_client.stub(:post) do |data, headers|
        response_mapping.get_mapping(:post, build_url).call(build_url, data,
          headers)
      end
      rest_client.stub(:put) do |data, headers|
        response_mapping.get_mapping(:put, build_url).call(build_url, data,
          headers)
      end
      rest_client.stub(:delete) do |headers|
        response_mapping.get_mapping(:delete, build_url).call(build_url,
          headers)
      end
      rest_client.stub(:vapp_state=) do |value|
        current_vapp_state = value
      end
      rest_client.stub(:vapp_state) do
        current_vapp_state
      end
      rest_client.stub(:response_mapping) do
        response_mapping
      end
      rest_client.stub(:vapp_power_state=) do |value|
        vapp_power_state = value
      end
      rest_client.stub(:[]) do |value|
        @resource = value
        @rest_connection
      end

      rest_client
    end

    def build_url
      url + @resource
    end

    def nested(url)
      URI.parse(url).path
    end

    class MockRestClient
      class << self
        attr_accessor :log
      end
    end

    def create_mock_client
      @rest_connection = mock_rest_connection()
      file_uploader = mock("File Uploader")
      file_uploader.stub(:upload) do
        @rest_connection.vapp_state = @upload_file_state == "success" ?
          "disks_uploaded" : "disks_upload_failed"
      end
      conn = Connection::Connection.new(url, entities["organization"],
        control["time_limit_sec"]["http_request"], MockRestClient,
          @rest_connection, file_uploader)
      conn.stub(:file_uploader) do
        file_uploader
      end
      conn.stub(:rest_connection) do
        @rest_connection
      end
      conn
    end

    def create_mock_ovf_directory(string_io)
      directory = mock("Directory")
      # Actual content of the OVF is irrelevant as long as the client gives
      # back the same one given to it
      ovf_string = "ovf_string"
      ovf_string_io = StringIO.new(ovf_string)
      directory.stub(:ovf_file_path) { "ovf_file" }
      directory.stub(:ovf_file) {
        ovf_string_io
      }
      directory.stub(:vmdk_file_path) do |file_name|
        file_name
      end
      directory.stub(:vmdk_file) do |file_name|
        string_io
      end
      directory
    end

    def create_mock_media_file()
      media_string = Test::Response::MEDIA_CONTENT
      string_io = StringIO.new(media_string)
      string_io.stub(:path) { "bogus/bogus.iso" }
      string_io.stub(:stat) {
        o = Object.new
        o.stub(:size) { media_string.length }
        o
      }
      string_io
    end


    describe "VCD Adapter client", :positive, :min, :all do
      it "logs into organization with usename and password and get the " +
         "organization VDC" do
        conn = mock("Connection")
        root_session = Xml::WrapperFactory.wrap_document(
          Test::Response::SESSION)
        vcloud_response = Xml::WrapperFactory.wrap_document(
          Test::Response::VCLOUD_RESPONSE)
        admin_org_response = Xml::WrapperFactory.wrap_document(
          Test::Response::ADMIN_ORG_RESPONSE)
        vdc_response = Xml::WrapperFactory.wrap_document(
          Test::Response::VDC_RESPONSE)
        conn.should_receive(:connect).with(username, password).and_return(
          root_session)
        conn.should_receive(:get).with(root_session.admin_root).and_return(
          vcloud_response)
        conn.should_receive(:get).with(vcloud_response.organization(
          entities["organization"])).and_return(admin_org_response)
        Client.new(nil, username, password, entities, control, conn)
      end
    end

    describe "VCD Adapter client", :upload, :all do
      it "uploads an OVF to the OVDC", :positive do
        vmdk_string = "vmdk"
        vmdk_string_io = StringIO.new(vmdk_string)
        directory = create_mock_ovf_directory(vmdk_string_io)

        conn = create_mock_client

        vapp_name = Test::Response::VAPP_TEMPLATE_NAME

        client = Client.new(nil, username, password, entities, control, conn)

        conn.file_uploader.should_receive(:upload).with(
          Test::Response::VAPP_TEMPLATE_DISK_UPLOAD_1, vmdk_string_io,
            auth_cookies)
        catalog_item = client.upload_vapp_template(vapp_name, directory)
        # Since the wrapper classes are used to hide away the raw XML,
        # compare the wrapped versions
        catalog_item.should eq(Xml::WrapperFactory.wrap_document(
          Test::Response::CATALOG_ADD_ITEM_RESPONSE))
      end

      it "reports an exception upon error in transferring an OVF file",
          :negative do
        vmdk_string = "vmdk"
        vmdk_string_io = StringIO.new(vmdk_string)
        directory = create_mock_ovf_directory(vmdk_string_io)

        conn = create_mock_client
        @upload_file_state = "failed"
        vapp_name = Test::Response::VAPP_TEMPLATE_NAME
        client = Client.new(nil, username, password, entities, control, conn)

        conn.file_uploader.should_receive(:upload).with(
          Test::Response::VAPP_TEMPLATE_DISK_UPLOAD_1, vmdk_string_io,
            auth_cookies)
        expect {
          client.upload_vapp_template(vapp_name, directory)
        }.to raise_exception("Error uploading vApp template")
        @upload_file_state = "success"
      end

      it "deletes the vApp template if there's an error uploading it to " +
         "the catalog", :negative do
        vmdk_string = "vmdk"
        vmdk_string_io = StringIO.new(vmdk_string)
        directory = create_mock_ovf_directory(vmdk_string_io)

        conn = create_mock_client
        conn.rest_connection.response_mapping[:post][
            Test::Response::CATALOG_ADD_ITEM_LINK] =
              lambda { |url, data, headers|
          raise ApiError, "Bogus add to catalog error"
        }
        vapp_name = Test::Response::VAPP_TEMPLATE_NAME
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::VAPP_TEMPLATE_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        client = Client.new(nil, username, password, entities, control, conn)
        expect {
          client.upload_vapp_template(vapp_name, directory)
        }.to raise_exception("Bogus add to catalog error")
      end

    end

    describe "VCD Adapter client", :delete, :all do
      it "deletes a vApp template from the catalog", :positive do
        vmdk_string = "vmdk"
        vmdk_string_io = StringIO.new(vmdk_string)
        directory = create_mock_ovf_directory(vmdk_string_io)

        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        vapp_name = Test::Response::VAPP_TEMPLATE_NAME
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::VAPP_TEMPLATE_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        catalog_item = client.upload_vapp_template(vapp_name, directory)
        client.delete_catalog_vapp(catalog_item.urn)
      end

      it "no exception for delete catalog vapp if the vApp does not exist",
          :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        client.delete_catalog_vapp("bogus")
      end

      it "raise exception for upload media to catalog if the catalog does " +
         "not exist", :negative do
        conn = create_mock_client
        ent_clone = entities.clone
        ent_clone["media_catalog"] = "bogus"
        media_file = create_mock_media_file()
        client = Client.new(nil, username, password, ent_clone, control, conn)
        media_name = Test::Response::MEDIA_NAME

        conn.file_uploader.stub(:upload) do |href, data, headers|
          href.should eq(Test::Response::MEDIA_ISO_LINK)
          data.read.should eq(Test::Response::MEDIA_CONTENT)
        end
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::MEDIA_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        expect {
          client.upload_catalog_media(media_name, media_file)
        }.to raise_exception(/.+ catalog .+ not found\./)
      end

      it "should not raise if underlying vApp no longer exists when " +
         "deleting a vApp from the catalog", :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        conn.rest_connection.response_mapping[:delete][
            Test::Response::VAPP_TEMPLATE_LINK] = lambda { |urls, headers|
          raise RestClient::ResourceNotFound
        }
        client.delete_catalog_vapp(Test::Response::VAPP_TEMPLATE_NAME)
      end
    end

    describe "VCD Adapter client", :instantiate_template, :all do
      xit "instantiates a vApp from the catalog", :positive do
        # marked pending because it failed on our local dev environment,
        # and it's unclear if BOSH team is going to maintain ownership
        # of this gem
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::VAPP_TEMPLATE_INSTANTIATE_LINK))
        conn.rest_connection.should_receive(:post).with(
          Test::Response::EXISTING_VAPP_TEMPLATE_INSTANTIATE_REQUEST,
            anything())
        client.instantiate_vapp_template(catalog_vapp_id, vapp_name)
      end

      it "instantiates with locality a vApp from the catalog", :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::VAPP_TEMPLATE_INSTANTIATE_LINK))
        conn.rest_connection.should_receive(:post).with(
          Test::Response::
            EXISTING_VAPP_TEMPLATE_INSTANTIATE_WITH_LOCALITY_REQUEST,
          anything())
        client.instantiate_vapp_template(catalog_vapp_id, vapp_name, "desc",
          [ Test::Response::INDY_DISK_URL ])
      end

      it "instantiates raises an exception if the task fails", :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME
        conn.rest_connection.response_mapping[:get][
          Test::Response::EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_LINK] =
            lambda { |url, headers|
              Test::Response::
                EXISTING_VAPP_TEMPLATE_INSTANTIATE_TASK_ERROR_RESPONSE
            }
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        expect {
          client.instantiate_vapp_template(catalog_vapp_id, vapp_name)
        }.to raise_exception(/.+Creating Virtual.+did not complete success.+/)
      end

    end

    describe "VCD Adapter client", :modify_vm, :all do
      it "reconfigures a VM", :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::RECONFIGURE_VM_LINK))
        conn.rest_connection.should_receive(:post).with(
          Test::Response::RECONFIGURE_VM_REQUEST, anything())
        vapp = client.instantiate_vapp_template(catalog_vapp_id, vapp_name)
        vm = vapp.vms.first
        client.reconfigure_vm(vm) do |v|
          vm.name = Test::Response::CHANGED_VM_NAME
          vm.description = Test::Response::CHANGED_VM_DESCRIPTION
          v.change_cpu_count(Test::Response::CHANGED_VM_CPU)
          v.change_memory(Test::Response::CHANGED_VM_MEMORY)
          v.add_hard_disk(Test::Response::CHANGED_VM_DISK)
          v.delete_nic(*vm.hardware_section.nics)
        end
      end

      xit "gets information on HD", :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        vm = vapp.vms.first
        vm.hardware_section.hard_disks.each do |h|
          h.capacity_mb.should_not be_nil
          h.disk_id.should_not be_nil
          h.bus_sub_type.should_not be_nil
          h.bus_type.should_not be_nil
        end

         vm.hardware_section.nics.each do |n|
          n.mac_address.should_not be_nil
        end

      end

    end

    describe "VCD Adapter client", :power_vapp, :all do
      it "finds and powers on a vApp and powers it off" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_ON_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_OFF_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_on_vapp(vapp)
        client.power_off_vapp(vapp, false)
      end

      it "finds and powers on a powered-on vApp" , :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_on_vapp(vapp)
        conn.rest_connection.should_not_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_ON_LINK))
        conn.rest_connection.should_not_receive(:post).with(
          anything(), anything())
        client.power_on_vapp(vapp)
      end

      it "finds and powers off a powered-off vApp" , :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_off_vapp(vapp, false)
        conn.rest_connection.should_not_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_OFF_LINK))
        conn.rest_connection.should_not_receive(:post).with(
          anything(), anything())
        client.power_off_vapp(vapp, false)
      end

      it "finds and powers on a vApp and undeploys it" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_ON_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_UNDEPLOY_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_on_vapp(vapp)
        client.power_off_vapp(vapp)
      end

      it "finds and undeploys an undeployed vapp" , :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_off_vapp(vapp)
        conn.rest_connection.should_not_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_UNDEPLOY_LINK))
        conn.rest_connection.should_not_receive(:post).with(
          anything(), anything())
        client.power_off_vapp(vapp)
      end

      it "finds and undeploys a powered-off vapp" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_on_vapp(vapp)
        client.power_off_vapp(vapp, false)
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_UNDEPLOY_LINK))
        conn.rest_connection.should_receive(:post).with(
          Test::Response::UNDEPLOY_PARAMS, anything())
        client.power_off_vapp(vapp)
      end

      it "discards state of a suspended vapp" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.response_mapping[:get][
          Test::Response::EXISTING_VAPP_LINK] = lambda { |url, headers|
            Test::Response::INSTANTIATED_SUSPENDED_VAPP_RESPONSE }
        conn.rest_connection.vapp_power_state = "suspended"

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_DISCARD_STATE_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())

        client.discard_suspended_state_vapp(vapp)
      end

      it "finds and powers on a vApp and reboots it" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_ON_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_POWER_REBOOT_LINK))
        conn.rest_connection.should_receive(:post).with(
          anything(), anything())
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_on_vapp(vapp)
        client.reboot_vapp(vapp)
      end

      it "reboot of a powered-off vApp raises an exception" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        expect {
          client.reboot_vapp(vapp)
        }.to raise_exception(VappPoweredOffError)
      end

      it "reboot of a suspended vApp raises an exception" , :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        conn.rest_connection.vapp_power_state = "suspended"

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        expect {
          client.reboot_vapp(vapp)
        }.to raise_exception(VappSuspendedError)
      end
    end

    describe "VCD Adapter client", :delete_vapp, :all do
      it "finds a vApp and deletes it without undeploying", :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        conn.rest_connection.should_not_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_UNDEPLOY_LINK))
        conn.rest_connection.should_not_receive(:post).with(
          anything(), anything())
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INSTANTIATED_VAPP_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        client.delete_vapp(vapp)
      end

      it "finds and powers on a vApp and fails on delete vApp", :negative do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.power_on_vapp(vapp)
        conn.rest_connection.should_receive(:[]).once.with(
          nested(Test::Response::INSTANTIATED_VAPP_LINK))
        conn.rest_connection.should_not_receive(:delete).with(anything())
        expect {
          client.delete_vapp(vapp)
        }.to raise_exception(/vApp .+ powered on, power-off before deleting./)
      end
    end

    describe "VCD Adapter client", :add_vapp_network, :all do
      it "finds a network and vapp and adds the network to the vApp",
          :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        network_name = Test::Response::ORG_NETWORK_NAME
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        network  = client.get_ovdc.available_networks.find {
          |n| n["name"] == network_name }
        conn.rest_connection.should_receive(:[]).with(nested(
          Test::Response::INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK))
        conn.rest_connection.should_receive(:put).with(Test::Response::
            INSTANTIATED_VAPP_NETWORK_CONFIG_ADD_NETWORK_REQUEST,
          anything())
        client.add_network(vapp, network)
      end

      it "removes all networks", :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.response_mapping[:put][
          Test::Response::INSTANTIATED_VAPP_NETWORK_CONFIG_SECTION_LINK] =
            lambda { |url, data, headers|
              expected = Xml::WrapperFactory.wrap_document(
                Test::Response::
                  INSTANTIATED_VAPP_NETWORK_CONFIG_REMOVE_NETWORK_REQUEST)
              received =  Xml::WrapperFactory.wrap_document(data)
              received.should eq(expected)
              Test::Response::
                INSTANTIATED_VAPP_NETWORK_CONFIG_MODIFY_NETWORK_TASK_SUCCESS
            }
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        client.delete_networks(vapp)
      end
    end

    describe "VCD Adapter client", :add_remove_insert_media, :all do
      it "uploads media to VDC and adds it to the catalog", :positive do
        conn = create_mock_client
        media_file = create_mock_media_file()
        client = Client.new(nil, username, password, entities, control, conn)
        media_name = Test::Response::MEDIA_NAME

        conn.file_uploader.stub(:upload) do |href, data, headers|
          href.should eq(Test::Response::MEDIA_ISO_LINK)
          data.read.should eq(Test::Response::MEDIA_CONTENT)
        end

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::CATALOG_ADD_ITEM_LINK))
        conn.rest_connection.should_receive(:post).with(
          Test::Response::MEDIA_ADD_TO_CATALOG_REQUEST, anything())

        client.upload_catalog_media(media_name, media_file)

      end

      it "deletes a media from catalog and the VDC", :positive do
        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        media_name = Test::Response::EXISTING_MEDIA_NAME

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::EXISTING_MEDIA_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::EXISTING_MEDIA_CATALOG_ITEM_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        client.delete_catalog_media(media_name)

      end

      it "uploads media to VDC, fails to add to catalog, and rolls back",
          :negative do
        conn = create_mock_client
        media_file = create_mock_media_file()
        client = Client.new(nil, username, password, entities, control, conn)
        media_name = Test::Response::MEDIA_NAME

        conn.rest_connection.response_mapping[:post][
            Test::Response::CATALOG_ADD_ITEM_LINK] = lambda {
              |url, data, headers|
          raise ApiError, "bogus error"
        }

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::MEDIA_LINK))
        conn.rest_connection.should_receive(:delete).with(anything())
        expect {
          client.upload_catalog_media(media_name, media_file)
        }.to raise_exception(/bogus error/)

      end

      it "inserts a media into a VM", :positive do
        conn = create_mock_client

        client = Client.new(nil, username, password, entities, control, conn)
        media_name = Test::Response::EXISTING_MEDIA_NAME

        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME

        vapp = client.instantiate_vapp_template(catalog_vapp_id, vapp_name)
        vm = vapp.vms.first
        client.insert_catalog_media(vm, media_name)

      end

    end

    describe "VCD Adapter client", :metadata, :all do
      it "sets and gets metadata on a VM", :positive do
        conn = create_mock_client

        client = Client.new(nil, username, password, entities, control, conn)

        metadata_key = Test::Response::METADATA_KEY
        metadata_value = Test::Response::METADATA_VALUE
        vapp = client.get_vapp(Test::Response::EXISTING_VAPP_URN)
        vm = vapp.vms.first
        client.set_metadata(vm, metadata_key, metadata_value)
        value = client.get_metadata(vm, metadata_key)
        value.should eq metadata_value
      end

    end

    describe "VCD Adapter client", :indy_disk, :all do
      it "creates an indepdent disk", :positive do
        disk_name = Test::Response::INDY_DISK_NAME
        disk_size = Test::Response::INDY_DISK_SIZE

        conn = create_mock_client

        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::VDC_INDY_DISKS_LINK))
        conn.rest_connection.should_receive(:post).with(
          Test::Response::INDY_DISK_CREATE_REQUEST, anything())

        client.create_disk(disk_name, disk_size)

      end

      it "creates an indepdent disk but hits an error", :negative do
        disk_name = Test::Response::INDY_DISK_NAME
        disk_size = Test::Response::INDY_DISK_SIZE

        conn = create_mock_client

        client = Client.new(nil, username, password, entities, control, conn)

        conn.rest_connection.response_mapping[:post][
          Test::Response::VDC_INDY_DISKS_LINK] = lambda {
              |href, data, headers|
            Test::Response::INDY_DISK_CREATE_ERROR
          }
        expect {
          client.create_disk(disk_name, disk_size)
        }.to raise_exception(ApiRequestError)

      end

      it "attaches an indepdent disk to a VM and then detaches", :positive do
        disk_name = Test::Response::INDY_DISK_NAME

        conn = create_mock_client

        client = Client.new(nil, username, password, entities, control, conn)

        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME

        vapp = client.instantiate_vapp_template(catalog_vapp_id, vapp_name)
        vm = vapp.vms.first

        vdc = client.get_ovdc()
        disk = vdc.disks(disk_name).first

        conn.rest_connection.response_mapping[:post][
          Test::Response::INSTANTIATED_VM_ATTACH_DISK_LINK] = lambda {
              |href, data, headers|
            data_xml = Nokogiri::XML(data)
            expected_xml = Nokogiri::XML(
              Test::Response::INDY_DISK_ATTACH_REQUEST)
            equality = VCloudSdk::Test::compare_xml(data_xml, expected_xml)
            equality.should == true
            Test::Response::INDY_DISK_ATTACH_TASK
          }

        client.attach_disk(disk, vm)

        conn.rest_connection.response_mapping[:post][
          Test::Response::INSTANTIATED_VM_DETACH_DISK_LINK] = lambda {
              |href, data, headers|
            data_xml = Nokogiri::XML(data)
            expected_xml = Nokogiri::XML(
              Test::Response::INDY_DISK_DETACH_REQUEST)
            equality = VCloudSdk::Test::compare_xml(data_xml, expected_xml)
            equality.should == true
            Test::Response::INDY_DISK_DETACH_TASK
          }

        client.detach_disk(disk, vm)


      end

      it "attaches an indepdent disk to a VM but has an error", :negative do
        disk_name = Test::Response::INDY_DISK_NAME

        conn = create_mock_client

        client = Client.new(nil, username, password, entities, control, conn)

        catalog_vapp_id = Test::Response::EXISTING_VAPP_TEMPLATE_CATALOG_URN
        vapp_name = Test::Response::VAPP_NAME

        vapp = client.instantiate_vapp_template(catalog_vapp_id, vapp_name)
        vm = vapp.vms.first

        vdc = client.get_ovdc()
        disk = vdc.disks(disk_name).first

        conn.rest_connection.response_mapping[:post][
          Test::Response::INSTANTIATED_VM_ATTACH_DISK_LINK] = lambda {
              |href, data, headers|
            Test::Response::INDY_DISK_ATTACH_TASK_ERROR
          }

        expect {
          client.attach_disk(disk, vm)
        }.to raise_exception(/.+ Attaching Disk .+ complete successfully\./)

      end

      it "deletes an independent disk", :positive do
        disk_name = Test::Response::INDY_DISK_NAME

        conn = create_mock_client
        client = Client.new(nil, username, password, entities, control, conn)
        vdc = client.get_ovdc()
        disk = vdc.disks(disk_name).first
        conn.rest_connection.should_receive(:[]).with(
          nested(Test::Response::INDY_DISK_URL))
        conn.rest_connection.should_receive(:delete).with(anything())
        client.delete_disk(disk)
      end

    end

  end
end

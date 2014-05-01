module VSphereCloud
  class FileProvider
    include RetryBlock

    def initialize(rest_client, vcenter_host)
      @vcenter_host = vcenter_host
      @rest_client = rest_client
    end

    def fetch_file(datacenter_name, datastore_name, path)
      retry_block do
        url ="https://#{@vcenter_host}/folder/#{path}?dcPath=#{URI.escape(datacenter_name)}" +
          "&dsName=#{URI.escape(datastore_name)}"

        response = @rest_client.get(url)

        if response.code < 400
          response.body
        elsif response.code == 404
          nil
        else
          raise "Could not fetch file: #{url}, status code: #{response.code}"
        end
      end
    end

    def upload_file(datacenter_name, datastore_name, path, contents)
      retry_block do
        url = "https://#{@vcenter_host}/folder/#{path}?dcPath=#{URI.escape(datacenter_name)}" +
          "&dsName=#{URI.escape(datastore_name)}"

        response = @rest_client.put(
          url,
          contents,
          { 'Content-Type' => 'application/octet-stream', 'Content-Length' => contents.length })

        unless response.code < 400
          raise "Could not upload file: #{url}, status code: #{response.code}"
        end
      end
    end
  end
end

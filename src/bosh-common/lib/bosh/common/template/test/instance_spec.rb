module Bosh::Common::Template::Test
  class InstanceSpec
    def initialize(
      address: 'my.bosh.com',
      az: 'az1',
      bootstrap: false,
      deployment: 'my-deployment',
      id: 'xxxxxx-xxxxxxxx-xxxxx',
      index: 0,
      ip: '192.168.0.0',
      name: 'me',
      networks: { 'network1' => { 'foo' => 'bar', 'ip' => '192.168.0.0' } }
    )
      @address = address
      @az = az
      @bootstrap = bootstrap
      @deployment = deployment
      @id = id
      @index = index
      @ip = ip
      @name = name
      @networks = networks
    end

    def to_h
      {
        'address' => @address,
        'az' => @az,
        'bootstrap' => @bootstrap,
        'deployment' => @deployment,
        'id' => @id,
        'index' => @index,
        'ip' => @ip,
        'name' => @name,
        'networks' => @networks,
        'job' => { 'name' => @name }
      }
    end
  end
end

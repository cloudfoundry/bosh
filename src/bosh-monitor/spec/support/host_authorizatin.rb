# Required since host-authorization was added
#   https://github.com/sinatra/sinatra/pull/2053

RSpec.configure do |config|
  config.before(:suite) do
    Sinatra::Base.set(
      :host_authorization,
      { permitted_hosts: ['example.org'] }
    )
  end
end

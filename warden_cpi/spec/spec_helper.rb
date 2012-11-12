require "cloud"

require "cloud/warden"

def cloud_options
  {
    "warden" => warden_options,
  }
end

def warden_options
  {
    "unix_domain_socket" => "/tmp/warden.sock",
  }
end

module Bosh::Monitor

  class ApiController < Sinatra::Base

    configure do
      set(:show_exceptions, false)
      set(:raise_errors, false)
      set(:dump_errors, false)
    end

    get "/varz" do
      content_type(:json)
      Yajl::Encoder.encode(Bhm.varz, :terminator => "\n")
    end

  end

end

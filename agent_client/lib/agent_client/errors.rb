# encoding: UTF-8

module Bosh
  module Agent

    class Error < StandardError; end
    class AuthError < Error; end
    class HandlerError < StandardError; end

  end
end

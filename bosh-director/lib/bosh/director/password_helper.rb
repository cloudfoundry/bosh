require 'securerandom'
require 'unix_crypt'

module Bosh::Director
  module PasswordHelper
    # SHA512 tolerates salt lengths from 8 to 16 bytes
    # we found this by using the mkpasswd (from the whois package) on ubuntu linux
    SALT_MAX_LENGTH_IN_BYTES = 16

    PASSWORD_LENGTH = 30

    def sha512_hashed_password
      salt = SecureRandom.hex(SALT_MAX_LENGTH_IN_BYTES / 2)
      password = SecureRandom.hex(PASSWORD_LENGTH)
      UnixCrypt::SHA512.build(password, salt)
    end
  end
end
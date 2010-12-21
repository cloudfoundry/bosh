module Bosh::Director
  class UserManager

    def authenticate(username, password)
      user = Models::User.find(:username => username).first
      authenticated = user && BCrypt::Password.new(user.password) == password
      if !authenticated && Models::User.all.size == 0
        authenticated = ["admin", "admin"] == [username, password]
      end
      authenticated
    end

    def delete_user(username)
      user = Models::User.find(:username => username).first
      raise UserNotFound if user.nil?
      user.mutex do
        user.delete
      end
    end

    def create_user(new_user)
      user = Models::User.new
      user.username = new_user.username
      user.password = BCrypt::Password.create(new_user.password).to_s
      user.save!
      user
    rescue Ohm::ValidationException => e
      raise UserNameTaken.new(user.username) if e.errors.include?([:username, :not_unique])
      raise UserInvalid.new(user.errors.join(" "))
    end

    def update_user(updated_user)
      user = Models::User.find(:username => updated_user.username).first
      raise UserNotFound if user.nil?
      user.password = BCrypt::Password.create(updated_user.password).to_s
      user.save!
      user
    rescue Ohm::ValidationException => e
      raise UserInvalid.new(user.errors.join(" "))
    end

    def get_user_from_request(request)
      user = Models::User.new
      hash = Yajl::Parser.new.parse(request.body)
      user.username = hash["username"]
      user.password = hash["password"]
      user
    end

  end
end

module Bosh::Director
  class UserManager

    def authenticate(username, password)
      user = Models::User.find(:username => username).first
      authenticated = user && user.password == password
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

    def create_user(user)
      raise UserInvalid.new(user.errors) unless user.valid?
      user.create
    end

    def update_user(user)
      original_user = Models::User.find(:username => user.username).first
      raise UserNotFound if original_user.nil?
      user.id = original_user.id
      raise UserInvalid.new(user.errors) unless user.valid?
      user.save
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
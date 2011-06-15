class UserSession < Authlogic::Session::Base

  def self.create_from_shibboleth(identity)
    create(User.find_or_create_from_shibboleth(identity))
  end

  def self.create_from_id(id)
    create(User.find(id))
  end
end

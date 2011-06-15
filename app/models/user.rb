class User < ActiveRecord::Base
	include OhioStatePerson

	belongs_to :owner, :polymorphic => true
	has_many :authorizations

	acts_as_authentic do |c|
		c.validate_password_field = false
	end

	def self.find_or_create_from_shibboleth(identity)
		user = find_or_create_by_emplid(identity)

		# names change due to marriage, etc.
		# update_attribute is a NOOP if not different
		user.update_attribute(:name_n, identity[:name_n])

		user
	end

	def admin?
		role == 'admin'
	end

	def authorized?
		admin? or !!Authorization.find_by_user_id(self.id)
	end

	def advisor?
		find_owner if owner_type.nil?
		owner_type == 'Advisor' and authorized?
	end

	def advisor
		Advisor.find_by_emplid(self.emplid)
	end

	def student?
		find_owner if owner_type.nil?
		owner_type == 'Student'
	end

	def student
		Student.find_by_emplid(self.emplid)
	end

	def other_owner
		return Advisor.find_by_emplid(self.emplid) if owner.kind_of?(Student)
		return Student.find_by_emplid(self.emplid) if owner.kind_of?(Advisor)
	end

  def switchable?
    if other_owner.present? && other_owner.kind_of?(Student)
      true
    elsif other_owner.present? && other_owner.kind_of?(Advisor)
      authorized?
    end
  end

	def alternate_owner!
		update_attribute(:owner, other_owner) if switchable?
	end

	private

	def find_owner
		if (advisor = Advisor.find_by_emplid(self.emplid)) and authorized?
      update_attribute(:owner, advisor)
		elsif student = Student.find_by_emplid(self.emplid)
			update_attribute(:owner, student)
		end
	end

end

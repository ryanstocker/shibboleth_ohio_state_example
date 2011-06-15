class ApplicationController < ActionController::Base

  include SslRequirement

	protect_from_forgery

	helper_method :current_user, :current_user_session

	before_filter :require_user

	private

	def authenticated?
		request.env['employeeNumber'].present?
	end

	def shibboleth
		{:emplid => request.env['employeeNumber'],
		 :name_n => request.env['REMOTE_USER'].chomp("@osu.edu")}
	end

	def current_user_session
		if session[:simulate_id].present?
      @current_user_session = UserSession.create_from_id(session[:simulate_id])
    elsif defined?(@current_user_session)
			@current_user_session
		elsif @current_user_session = UserSession.find
			@current_user_session
		elsif authenticated?
			@current_user_session = UserSession.create_from_shibboleth(shibboleth)
		end
	end

	def current_user
		return @current_user if defined?(@current_user)
		@current_user = current_user_session && current_user_session.user
	end

	def require_user
		unless current_user
			if Rails.env.production?
				base = request.protocol + request.host
				requested_url = base + request.request_uri
				redirect_to [base, '/Shibboleth.sso/Login?target=',
					CGI.escape(requested_url)].join
			else
				redirect_to new_user_session_url, :notice => 'Login first, please.'
			end
		end
	end

	def admin_required
		unless current_user.admin?
			redirect_to root_url, :notice => "You must be an administrator to access this page"
		end
	end

	def advisor_required
		if current_user.student? and current_user.switchable?
			current_user.alternate_owner!
		end
		if current_user.advisor?
			@advisor = current_user.owner
		else
			redirect_to root_url, :notice => "You must be an advisor to access this part of the system"
		end
	end

	def student_required
		if current_user.advisor? and current_user.switchable?
			current_user.alternate_owner!
		end
		if current_user.student?
			@student = current_user.owner
			redirect_to student_disclaimer_url if !current_user.agreed_to_student_usage?
		else
			redirect_to root_url, :notice => "You must be a student to access this part of the system"
		end
	end


	protected

	#require SSL only in production
	def ssl_required?
		Rails.env.production?
	end

end

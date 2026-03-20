class ApplicationController < ActionController::Base
  private

    # Stub authentication for the example app.
    # In a real app, this would come from forward-auth middleware.
    def current_user = OpenStruct.new(uid: "demo", email: "demo@localhost")
    helper_method :current_user

    def authenticate_user!
      head :unauthorized unless current_user
    end
end

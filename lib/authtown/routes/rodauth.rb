# frozen_string_literal: true

module Authtown
  module Routes
    class InitRodauth < Bridgetown::Rack::Routes
      priority :highest

      route do |r|
        rodauth.load_memory

        init_current_user
        Lifeform::Form.rodauth = rodauth

        r.on "auth" do
          r.rodauth
        end
      end

      def current_user = Authtown::Current.user

      def init_current_user
        Authtown::Current.user =
          if rodauth.logged_in?
            account_id = rodauth.account_from_session[:id]
            Authtown::Current.user&.id == account_id ? Authtown::Current.user : User.find(account_id)
          end
      end
    end
  end
end

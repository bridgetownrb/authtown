# frozen_string_literal: true

module Authtown
  module Routes
    class InitRodauth < Bridgetown::Rack::Routes
      priority :highest

      route do |r|
        rodauth.load_memory

        init_current_user

        # hook :authtown, :initialized do |rodauth|
        #   Lifeform::Form.rodauth = rodauth
        # end
        Bridgetown::Hooks.trigger(:authtown, :initialized, rodauth)

        r.on "auth" do
          r.rodauth
        end
      end

      def init_current_user
        Authtown::Current.user =
          if rodauth.logged_in?
            account_id = rodauth.account_from_session[:id]
            user_class = bridgetown_site.config.authtown.user_class_resolver.()
            user_class[account_id]
          end
      end
    end
  end
end

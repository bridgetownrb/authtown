# frozen_string_literal: true

module Authtown
  module Routes
    class InitRodauth < Bridgetown::Rack::Routes
      priority :highest

      route do |r|
        rodauth.load_memory

        init_current_user

        # @example hook usage:
        #   hook :authtown, :initialized do |rodauth|
        #     Lifeform::Form.rodauth = rodauth
        #   end
        Bridgetown::Hooks.trigger(:authtown, :initialized, rodauth)

        r.on "auth" do
          r.rodauth
        end
      end

      def init_current_user
        Authtown::Current.user =
          if rodauth.logged_in?
            # load existing account hash into Model:
            bridgetown_site.config.authtown.user_class_resolver.().(rodauth.account_from_session)
          end
      end
    end
  end
end

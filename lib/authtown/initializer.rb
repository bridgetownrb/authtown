# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
# @param config [Bridgetown::Configuration::ConfigurationDSL]
# @param rodauth_config [Proc]
# @param account_landing_page [String] relative URL to redirect to upon login / create account
# @param user_class_resolver [Proc] return the class of the user model
# @param user_name_field [String] save a name when creating a new user, or set to nil to skip
Bridgetown.initializer :authtown do |
  config,
  rodauth_config: nil,
  account_landing_page: "/account/profile",
  user_class_resolver: -> { User },
  user_name_field: :first_name
  |

  config.authtown ||= {}
  config.authtown.user_class_resolver ||= user_class_resolver

  config.only :server do
    require "authtown/routes/rodauth"

    # @param app [Class<Roda>]
    config.roda do |app|
      app.prepend Authtown::ViewMixin

      secret = ENV.fetch("RODA_SECRET_KEY")
      app.plugin(:sessions, secret:)

      app.plugin :rodauth, render: false do
        enable :login, :logout, :create_account, :remember, :reset_password, :internal_request
        hmac_secret secret

        base_url config.url

        prefix "/auth"

        login_redirect account_landing_page
        create_account_redirect account_landing_page
        logout_redirect "/"

        set_deadline_values? true # for remember, etc.
        # TODO: why isn't this working? might be a schema issue with old AR:
        remember_deadline_interval days: 30
        extend_remember_deadline? true

        login_label "Email Address"
        login_button "Sign In"

        accounts_table :users
        account_password_hash_column :password_hash

        require_login_confirmation? false
        require_password_confirmation? false

        # Require passwords to have at least 8 characters
        password_minimum_length 8

        # Don't allow passwords to be too long, to prevent long password DoS attacks
        password_maximum_length 64

        reset_password_email_sent_redirect "/account/reset-link-sent"
        reset_password_autologin? true
        reset_password_redirect account_landing_page

        before_create_account do
          # Ensure timestamps get saved
          account[:created_at] = account[:updated_at] = Time.now
          next unless user_name_field

          # Save name details
          account[user_name_field] = param(user_name_field) if param(user_name_field)
        end

        after_login do
          remember_login
        end

        instance_exec(&rodauth_config) if rodauth_config
      end
    end
  end

  # Register your builder:
  config.builder Authtown::Builder
end
# rubocop:enable Metrics/BlockLength

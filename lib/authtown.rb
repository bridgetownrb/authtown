# frozen_string_literal: true

require "bridgetown"
require "mail"
require "authtown/builder"
require "authtown/view_mixin"

# rubocop:disable Layout/LineLength
### Simple migration strategy:
#
# Sequel.migration do
#   change do
#     extension :date_arithmetic

#     create_table(:users) do
#       primary_key :id, type: :Bignum
#       citext :email, null: false
#       constraint :valid_email, email: /^[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+$/
#       String :first_name
#       String :password_hash, null: false
#       index :email, unique: true
#     end

#     # Used by the remember me feature
#     create_table(:account_remember_keys) do
#       foreign_key :id, :users, primary_key: true, type: :Bignum
#       String :key, null: false
#       DateTime :deadline, { null: false, default: Sequel.date_add(Sequel::CURRENT_TIMESTAMP, days: 30) }
#     end

#     create_table(:account_password_reset_keys) do
#       foreign_key :id, :users, primary_key: true, type: :Bignum
#       String :key, null: false
#       DateTime :deadline, { null: false, default: Sequel.date_add(Sequel::CURRENT_TIMESTAMP, days: 1) }
#       DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
#     end
#   end
# end
# rubocop:enable Layout/LineLength

Thread.attr_accessor :authtown_state
class Authtown::Current
  class << self
    def thread_state = Thread.current.authtown_state ||= {}

    def user=(new_user)
      thread_state[:user] = new_user
    end

    def user = thread_state[:user]
  end
end

# rubocop:disable Metrics/BlockLength
# @param config [Bridgetown::Configuration::ConfigurationDSL]
# @param rodauth_config [Proc]
Bridgetown.initializer :authtown do |
  config,
  rodauth_config: nil,
  account_landing_page: "/account/profile",
  user_class_resolver: -> { User }
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

      app.plugin :rodauth do
        enable :login, :logout, :create_account, :remember, :reset_password, :internal_request
        hmac_secret secret

        base_url config.url

        prefix "/auth"

        login_redirect account_landing_page
        create_account_redirect account_landing_page
        logout_redirect "/"

        set_deadline_values? true # for remember, etc.
        remember_deadline_interval days: 30 # TODO: why isn't this working?!
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
          # Make sure timestamps get saved
          account[:created_at] = account[:updated_at] = Time.now

          account[:first_name] = param(:first_name) if param(:first_name)
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

# frozen_string_literal: true

require "bridgetown"
require "mail"
require "authtown/builder"
require "authtown/view_mixin"

# REQUIRES:
# init :"bridgetown-activerecord", sequel_support: :postgres

# ActiveRecord schema:
#
# class CreateUsers < ActiveRecord::Migration[7.0]
#   def change
#     create_table :users do |t|
#       t.string :email, null: false, index: { unique: true }
#       t.string :first_name
#       t.string :password_hash, null: false
#       t.timestamps
#     end
#   end
# end
#
# class CreateAccountRememberKeys < ActiveRecord::Migration[7.0]
#   def change
#     create_table :account_remember_keys do |t|
#       t.foreign_key :users, column: :id
#       t.string :key, null: false
#       t.datetime :deadline, null: false
#     end
#   end
# end

class Authtown::Current < ActiveSupport::CurrentAttributes
  # @!parse def self.user = User.new
  attribute :user
end

# rubocop:disable Metrics/BlockLength
# @param config [Bridgetown::Configuration::ConfigurationDSL]
# @param rodauth_config [Proc]
Bridgetown.initializer :authtown do |
  config,
  rodauth_config: nil,
  account_landing_page: "/account/profile"
  |

  config.only :server do
    require "authtown/routes/rodauth"

    # @param app [Class<Roda>]
    config.roda do |app|
      app.prepend Authtown::ViewMixin

      secret = ENV.fetch("RODA_SECRET_KEY")
      app.plugin(:sessions, secret:)

      app.plugin :rodauth do
        enable :login, :logout, :create_account, :remember, :reset_password
        hmac_secret secret

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

          account[:first_name] = param(:first_name)
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

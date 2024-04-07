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

require "authtown/initializer"

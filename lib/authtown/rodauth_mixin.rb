# frozen_string_literal: true

# This gets prepended into the RodAuth class after plugin load
module Authtown::RodauthMixin
  def login_failed_reset_password_request_form
    # part of reset_password internals…no-op since we're rendering our own forms
  end
end

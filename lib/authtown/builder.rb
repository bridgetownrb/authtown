# frozen_string_literal: true

module Authtown
  class Builder < Bridgetown::Builder
    def build
      helper(:rodauth) { helpers.view.resource.roda_app&.rodauth }
      helper(:current_user) { Authtown::Current.user }
    end
  end
end

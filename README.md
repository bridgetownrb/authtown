# Authtown: Rodauth integration for Bridgetown

A Bridgetown plugin which provides authentication and account management via database access and SSR routes, powered by [Rodauth](https://rodauth.jeremyevans.net).

**WIP — public 1.0 release coming soon once Bridgetown 2.0 ships!**

## Installation

As a prerequisite to installing Authtown, make sure you've set up Sequel database access via the [bridgetown_sequel](https://github.com/bridgetownrb/bridgetown_sequel) plugin. You'll also need a way to send mail (Authtown will install the `mail` gem automatically) via a service like Sendgrid, Mailgun, etc. In addition, if you haven't already, you will need to add the `dotenv` and `bridgetown-routes` plugins as described in your `Gemfile` and `config/initializers.rb` file. Finally, for an easy way to generate account forms, install the [Lifeform](https://github.com/bridgetownrb/lifeform) plugin.

Run this command to add this plugin to your site's Gemfile:

```shell
bundle add authtown
```

You'll also need the lifeform gem to build the login form:
```shell
bundle add lifeform
```

Then set up a mail initializer file (in `config/mail.rb`):

```ruby
Bridgetown.initializer :mail do |password:|
  # set up options below for your particular email service
  Mail.defaults do
    delivery_method :smtp,
                    address: "smtp.sendgrid.net",
                    port: 465,
                    user_name: "apikey",
                    password:,
                    authentication: :plain,
                    tls: true
  end
end
```

And call that from your configuration in `config/initializers.rb`:

```ruby
only :server do
  init :mail, password: ENV.fetch("SERVICE_API_KEY", nil) # can come from .env file or hosting environment
end
```

Next, add Authtown's initialization for your configuration. Here's a basic set of options:

```ruby
init :lifeform

init :authtown do
  # Defaults, uncomment to modify:
  #
  # account_landing_page "/account/profile"
  # user_class_resolver -> { User }
  # user_name_field :first_name

  rodauth_config -> do
    email_from "Your Name <youremail@example.com>"

    reset_password_email_body do
      "Howdy! You or somebody requested a password reset for your account.\n" \
        "If that's legit, here's the link:\n#{reset_password_email_link}\n\n" \
        "Otherwise, you may safely ignore this message.\n\nThanks!\n–You @ Company"
    end

    enable :http_basic_auth if Bridgetown.env.test?

    # You can define additional options here as provided by Rodauth directly
  end
end
```

You will need to generate a secret key for Roda's session handling. Run `bin/bridgetown secret` to copy that into your .env file.

```env
RODA_SECRET_KEY=1f8dbd0da3a4...
```

You will also need to generate a Sequel migration for your user accounts. Here is an example, you can tweak as necessary. Run `bin/bridgetown db:migrations:new filename=create_users`, then edit the file:

```ruby
Sequel.migration do
  change do
    extension :date_arithmetic

    create_table(:users) do
      primary_key :id, type: :Bignum
      citext :email, null: false
      # Not available on SQLite
      constraint :valid_email, email: /^[^,;@ \r\n]+@[^,@; \r\n]+\.[^,@; \r\n]+$/
      String :first_name
      String :password_hash, null: false
      index :email, unique: true

      DateTime :created_at
      DateTime :updated_at
    end

    # Used by the remember me feature
    create_table(:account_remember_keys) do
      foreign_key :id, :users, primary_key: true, type: :Bignum
      String :key, null: false
      DateTime :deadline, { null: false, default: Sequel.date_add(Sequel::CURRENT_TIMESTAMP, days: 30) }
    end

    create_table(:account_password_reset_keys) do
      foreign_key :id, :users, primary_key: true, type: :Bignum
      String :key, null: false
      DateTime :deadline, { null: false, default: Sequel.date_add(Sequel::CURRENT_TIMESTAMP, days: 1) }
      DateTime :email_last_sent, null: false, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
```

Also create your User model:

```ruby
# ./models/user.rb

require "bcrypt"

class User < Sequel::Model
  def self.password_for_string(str) # helper method
    BCrypt::Password.create(str).to_s
  end
end
```

And then run `bin/bridgetown db:migrate`.

Now, let's set up our forms and auth pages. We'll begin by creating an Account form:

```ruby
# ./models/forms/account.rb

require "lifeform" # Needed because Zeitwerk will try loading Forms::Lifeform and then fail.

module Forms
  class Account < Lifeform::Form
    fields do
      field rodauth.login_param.to_sym,
            type: :email,
            label: rodauth.login_label,
            required: true,
            autocomplete: "username",
            autofocus: true
      field :first_name,
            label: "Your Name",
            autocomplete: "name",
            required: true
      field rodauth.password_param.to_sym,
            type: :password,
            label: rodauth.password_label,
            required: true,
            autocomplete: rodauth.password_field_autocomplete_value
      field :submit, type: :submit_button, label: rodauth.login_button
    end
  end
end
```

Next, let's create the pages for logging in or creating an account.

**src/_routes/auth/login.erb**

```erb
---<%
render_with do
  layout :page
  title "Sign In"
end
%>---

<% if rodauth.logged_in? %>
  <p style="text-align:center">
    It looks like you're already signed in. Would you like to <a href="/account/profile">view your profile?</a>
  </p>
<% end %>

<article>
  <%= render Forms::Account.new(id: "login-form", url: rodauth.login_path, class: "centered") do |f| %>
    <%= render "form_errors" %>
    <%=
      render f.field(
        rodauth.login_param,
        value: r.params[rodauth.login_param],
        aria: { invalid: rodauth.field_error(rodauth.login_param).present? }
      )
    %>
    <%=
      render f.field(
        rodauth.password_param,
        aria: { invalid: rodauth.field_error(rodauth.password_param).present? }
      ) %>
    <%=
      render f.field(:submit)
    %>
  <% end %>
</article>

<p>Need to reset password? <a href="<%= rodauth.reset_password_request_path %>">Guess so ➞</a></p>

<hr />

<p>Don't have an account yet? <a href="<%= rodauth.create_account_path %>">Sign up today!</a></p>
```

**src/_routes/auth/create-account.erb**

```erb
---<%
render_with do
  layout :page
  title "Sign Up"
end
%>---

<% if rodauth.logged_in? %>
  <p style="text-align:center">
    It looks like you're already signed in. Would you like to <a href="/account/profile">view your profile?</a>
  </p>
<% end %>

<article>
  <%= render Forms::Account.new(url: rodauth.create_account_path, class: "centered") do |f| %>
    <%= render "form_errors" %>
    <%=
      render f.field(
        rodauth.login_param,
        value: r.params[rodauth.login_param],
        aria: { invalid: rodauth.field_error(rodauth.login_param).present? }
      )
    %>
    <%=
      render f.field(
        :first_name,
        value: r.params[:first_name]
      )
    %>
    <%=
      render f.field(
        rodauth.password_param,
        aria: { invalid: rodauth.field_error(rodauth.password_param).present? }
      ) %>
    <%=
      render f.field(:submit, label: rodauth.create_account_button)
    %>
  <% end %>
</article>

<% unless rodauth.logged_in? %>
  <p style="text-align:center">Have an account already? <a href="/auth/login">Sign in here</a>.</p>
<% end %>
```

**src/_partials/form_errors.erb**

```erb
<form-errors>
  <p aria-live="assertive">
    <% if flash[:error] || rodauth.field_error(rodauth.login_param) || rodauth.field_error(rodauth.password_param) %>
      <%= flash[:error] %>:
      <br/>
      <small>
        <% if rodauth.field_error(rodauth.login_param) %>
          <%= rodauth.field_error(rodauth.login_param) %>
        <% end %>
        <% if rodauth.field_error(rodauth.password_param) %>
          <%= rodauth.field_error(rodauth.password_param) %>
        <% end %>
      </small>
    <% end %>
  </p>
</form-errors>
```

We'll still need ones for password reset, but let's hold off for the moment. We're almost ready to test this out, but you'll also need an account profile page for when the user's successfully signed in:

**src/_routes/account/profile.erb**

```erb
---<%
rodauth.require_authentication # always include this before logged-in only routes

render_with do
  layout :page
  title "Your Account"
end
%>---

<%= markdownify do %>

Welcome back, **<%= current_user.first_name %>**.

(other content here)

<% end %>

<hr />

<form method="post" action="<%= rodauth.logout_path %>">
  <%= csrf_tag(rodauth.logout_path) %>
  <p>You’re logged in as: <strong><%= current_user.email %></strong>.</p>
  <button type="submit"><%= rodauth.logout_button %></button>
</form>
```

At this point, you should be able to start up your Bridgetown site, navigate to `/auth/create-account`, and test creating an account, logging out, logging back in, etc.

As a final step, we'll need to handle password reset. Add the following pages:

**src/_routes/auth/reset-password-request.erb**

```erb
---<%
render_with do
  layout :page
  title "Reset Your Password"
end
%>---

<article>
<%= render Forms::Account.new(url: rodauth.reset_password_request_path, class: "centered") do |f| %>
  <%= render "form_errors" %>
  <%=
    render f.field(
      rodauth.login_param,
      value: r.params[rodauth.login_param],
      aria: { invalid: rodauth.field_error(rodauth.login_param).present? }
    )
  %>
  <%=
    render f.field(:submit, label: rodauth.reset_password_request_button)
  %>
<% end %>
</article>
```


**src/_routes/auth/reset-password.erb**

```erb
---<%
render_with do
  layout :page
  title "Save New Password"
end
%>---

<article>
<%= render Forms::Account.new(url: rodauth.reset_password_path, class: "centered") do |f| %>
  <%= render "form_errors" %>
  <%=
    render f.field(
      rodauth.password_param,
      aria: { invalid: rodauth.field_error(rodauth.password_param).present? }
    )
  %>
  <%=
    render f.field(:submit, label: rodauth.reset_password_button)
  %>
<% end %>
</article>
```

**src/_routes/account/reset-link-sent.erb**

```erb
---<%
render_with do
  layout :page
  title "Reset Link Sent"
end
%>---

<p style="text-align: center">Check your email, it should be arriving in just a moment.</p>
```

Now when you navigate to `/auth/reset-password-request`, you should be able to get a link for saving a new password.

## Testing the Gem

* Run `bundle exec rake test` to run the test suite
* Or run `script/cibuild` to validate with Rubocop and Minitest together.

## Contributing

1. Fork it (https://github.com/bridgetownrb/authtown)
2. Clone the fork using `git clone` to your local development machine.
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create a new Pull Request

# frozen_string_literal: true

# This gets prepended into the RodaApp class
module Authtown::ViewMixin
  def locals = @_route_locals

  def current_user = Authtown::Current.user

  ### Compatibility layer to translate Rodauth view calls to Bridgetown Routing

  # Return a single hash combining the template and opts arguments.
  def parse_template_opts(template, opts)
    opts = opts.to_h
    if template.is_a?(Hash)
      opts.merge!(template)
    else
      opts[:template] = template
      opts
    end
  end

  def find_template(opts) = opts

  def template_path(opts) = opts[:template]

  def login_failed_reset_password_request_form
    # part of reset_password internals…no-op since we're rendering our own forms
  end

  def view(*args, view_class: Bridgetown::ERBView, **kwargs) # rubocop:disable Metrics
    kwargs = args.first if args.first.is_a?(Hash)

    return super if kwargs.empty? # regular Bridgetown behavior

    unless kwargs.dig(:locals, :rodauth)
      raise "The `view' method with keyword arguments should only be used by Rodauth internally. " \
            "It is not supported by Bridgetown's view layer."
    end

    if kwargs.dig(:locals, :rodauth)&.prefix
      kwargs[:template] =
        "#{kwargs.dig(:locals, :rodauth).prefix.delete_prefix("/")}/#{kwargs[:template]}"
    end

    routes_manifest.routes.each do |route|
      file, localized_slugs = route
      next unless localized_slugs.first == kwargs[:template]

      return run_file_route(file, slug: localized_slugs.first)
    end

    Bridgetown.logger.warn("Rodauth template not found: #{kwargs[:template]}")
    nil # couldn't find template, 404
  end
end

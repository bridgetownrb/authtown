# frozen_string_literal: true

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

    # TODO: this should really be some sort of exposed method from the routes plugin
    response["X-Bridgetown-SSR"] = "1"

    Bridgetown::Routes::Manifest.generate_manifest(bridgetown_site).each do |route|
      file, localized_file_slugs = route

      file_slug = localized_file_slugs.first

      next unless file_slug == kwargs[:template]

      Bridgetown::Routes::CodeBlocks.eval_route_file file, file_slug, self
      route_block = Bridgetown::Routes::CodeBlocks.route_block(file_slug)
      response.instance_variable_set(
        :@_route_file_code, route_block.instance_variable_get(:@_route_file_code)
      ) # could be nil
      @_route_locals = kwargs[:locals]
      return instance_exec(request, &route_block)
    end

    Bridgetown.logger.warn("Rodauth template not found: #{kwargs[:template]}")
    nil # couldn't find template, 404
  end
end

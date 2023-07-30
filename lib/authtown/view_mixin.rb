# frozen_string_literal: true

module Authtown::ViewMixin
  def locals = @_route_locals

  # TODO: this is super hacky
  def view(*args, view_class: Bridgetown::ERBView, **kwargs) # rubocop:disable Metrics
    kwargs = args.first if args.first.is_a?(Hash)

    # If we're farming out to another view, let's go!
    unless kwargs.empty?
      response["X-Bridgetown-SSR"] = "1"

      # UGH, hate special casing this
      if kwargs.dig(:locals, :rodauth)&.prefix
        kwargs[:template] =
          "#{kwargs.dig(:locals, :rodauth).prefix.delete_prefix("/")}/#{kwargs[:template]}"
      end

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

      Bridgetown.logger.warn("Template not found: #{kwargs[:template]}")
      return nil # couldn't find template, 404
    end

    response._fake_resource_view(
      view_class:, roda_app: self, bridgetown_site:
    )
  end
end

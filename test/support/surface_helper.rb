# What the surface parity and hidden-person invariance tests (test/integration) share: read a
# page or an agent tool as one viewer, and compare not-found answers. Include it in the
# integration test that needs it; it is not mixed into every test.
module SurfaceHelper
  # Signed-in as the user, or signed out for nil (a visitor).
  def sign_in_or_out(viewer)
    viewer ? sign_in_as(viewer) : sign_out
  end

  def page_props = inertia.props.deep_symbolize_keys

  # The search prop of Home, which the page asks for with an Inertia partial reload.
  def partial_search(query, **params)
    get root_path, params: params.merge(q: query), headers: {
      "X-Inertia" => "true",
      "X-Inertia-Version" => InertiaRails.configuration.version.to_s,
      "X-Inertia-Partial-Component" => "home/index",
      "X-Inertia-Partial-Data" => "search"
    }
    response.parsed_body.fetch("props").fetch("search")
  end

  # An agent tool's parsed JSON result, as the acting member (the transport does not matter here).
  def tool_result(user, name, arguments = {})
    result = ToolRegistry.call(name, arguments:, user:, source: "webmcp")
    assert_equal false, result[:isError], result[:content].first[:text]
    JSON.parse(result[:content].first[:text], symbolize_names: true)
  end

  # The same request path is in every not-found body (the page url and og:url), so bodies
  # are compared with it masked.
  def masked_body(path) = response.body.gsub(%r{#{Regexp.escape(path)}(?![\w-])}, "/PATH")

  def not_found_answer(path)
    get path
    assert_response :not_found
    [ inertia.component, page_props, masked_body(path) ]
  end

  # The link-preview tags a crawler reads: the layout renders them server-side from page meta.
  def preview_meta
    css_select("meta[name=description], meta[property^='og:'], meta[name^='twitter:'], meta[name=robots]").map(&:to_s)
  end
end

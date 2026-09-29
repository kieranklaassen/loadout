module ApplicationHelper
  INLINE_CSS = Concurrent::Map.new

  # The built stylesheet plus the page component's own CSS (for example the home hero's), as
  # one inline <style>: first paint waits on the HTML alone, not on a stylesheet round trip.
  # Under the Vite dev server the CSS is served (and hot reloaded) by Vite, so it stays a link.
  def app_stylesheet_tag(component = nil)
    return vite_stylesheet_tag("application") if ViteRuby.instance.dev_server_running?

    manifest = ViteRuby.instance.manifest
    paths = [ manifest.path_for("application.css", type: :stylesheet) ]
    paths.concat(manifest.resolve_entries("~/pages/#{component}.tsx", type: :typescript)[:stylesheets]) if component
    tag.style(safe_join(paths.uniq.map { |path| inline_css(path) }))
  end

  private

  # Digested files never change, so one read per process is enough.
  def inline_css(path)
    INLINE_CSS.fetch_or_store(path) do
      File.read(File.join(ViteRuby.config.public_dir, path)).html_safe
    end
  end
end

# For pages read as the viewer (Home, Kind, Profile): the viewer's cookie decides what
# the response holds, so no shared cache may keep it.
module VariesByViewer
  extend ActiveSupport::Concern

  included do
    before_action :vary_by_viewer
  end

  private

  def vary_by_viewer
    expires_in 0.seconds, public: false, must_revalidate: true
    response.headers["Vary"] = "Cookie"
  end
end

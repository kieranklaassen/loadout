require "test_helper"

class Loadouts::PresenterTest < ActiveSupport::TestCase
  test "groups entries by category in catalog order with the go-to first" do
    categories = Loadouts::Presenter.new(users(:every_ana)).categories

    assert_equal %w[coding knowledge-work], categories.map { |category| category[:slug] }
    assert_equal "Cursor", categories.first[:entries].first[:tool][:name]
    assert_equal "My thinking partner.", categories.second[:entries].first[:note]
  end

  test "include_empty lists every category" do
    assert_equal Category.count, Loadouts::Presenter.new(users(:one)).categories(include_empty: true).size
  end
end

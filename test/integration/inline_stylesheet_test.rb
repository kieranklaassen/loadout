require "test_helper"

# First paint waits on the HTML alone: the CSS is inline and no stylesheet link blocks it.
class InlineStylesheetTest < ActionDispatch::IntegrationTest
  test "the home page inlines its CSS and requests no blocking stylesheet" do
    get "/"

    assert_response :success
    assert_equal 1, response.body.scan("<style>").size
    assert_select "link[rel=stylesheet]", false
    assert_includes response.body, ".hero"
    assert_not_includes response.body, "\"/assets/application-"
  end

  test "a page without its own CSS inlines only the application CSS" do
    get "/kinds/coding"

    assert_response :success
    assert_equal 1, response.body.scan("<style>").size
    assert_select "link[rel=stylesheet]", false
  end
end

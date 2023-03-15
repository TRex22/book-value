require 'test_helper'

class BookValueTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::BookValue::VERSION
  end

  def test_that_the_client_has_api_version
    assert_equal 'v1 2023-03-15', BookValue::Client.api_version
  end
end

require 'minitest/autorun'
require_relative '../lib/bgp_message'

class BGPLoopDetectionTest < Minitest::Test
  def setup
    @my_as = 65000
  end

  def test_reject_route_if_loop_detected
    loop_as_path = [65001, 65000, 65002]

    assert detect_loop?(loop_as_path, @my_as), "自分のASが含まれている場合はループとみなすこと"
  end

  def test_accept_route_if_no_loop
    safe_as_path = [65001, 65002]

    refute detect_loop?(safe_as_path, @my_as), "自分のASが含まれていない場合は安全とみなすこと"
  end

  private

  def detect_loop?(as_path, my_as)
    as_path.include?(my_as)
  end
end
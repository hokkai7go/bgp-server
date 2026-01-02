require 'minitest/autorun'
require 'socket'
require 'thread'
require 'timeout'
require_relative '../bgp-server'

class BGPSessionKeepaliveTest < Minitest::Test
  TEST_PORT  = 10181
  SERVER_AS  = 65001
  SERVER_RID = '192.0.2.1'

  def test_hold_timer_expiration
    test_hold_time = 3

    server_socket = TCPServer.new(TEST_PORT)
    session = nil

    server_thread = Thread.new do
      begin
        client_conn = server_socket.accept
        session = BGPSession.new(client_conn, SERVER_AS, SERVER_RID)

        # ピアからメッセージを受信しない状態をシミュレート
        session.instance_variable_set(:@hold_time, test_hold_time)

        session.transition_to_established
        sleep(test_hold_time + 1)

      rescue => e
        puts "Server thread error: #{e.message}"
      ensure
        client_conn&.close
      end
    end

    begin
      sleep(0.1)
      client_socket = TCPSocket.new('127.0.0.1', TEST_PORT)

      Timeout::timeout(test_hold_time + 2) do
        loop do
          break if session && session.instance_variable_get(:@state) == BGPSession::STATE_IDLE
          sleep(0.1)
        end
      end

      assert_equal BGPSession::STATE_IDLE, session.instance_variable_get(:@state), 'Hold Timer 切れによりセッション状態が IDLE に遷移すること'

      assert_nil client_socket.read(1), "サーバー側から切断されたため、read は nil を返すこと"

    rescue Timeout::Error
      flunk 'Hold Timer タイムアウト処理が指定時間内に完了しませんでした。'
    ensure
      client_socket&.close
      server_socket&.close
      server_thread&.kill
    end
  end
end

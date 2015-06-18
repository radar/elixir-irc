defmodule IRCServerTest do
  use ExUnit.Case
  import SocketHelpers

  setup do
     :application.stop(:irc)
     :ok = :application.start(:irc)
   end

  setup do
    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 6667, opts)
    {:ok, socket: socket}
  end

  test "server login", %{socket: socket} do
    send_message(socket, "NICK Radar")
    send_message(socket, "USER textual 0 * :Textual User")
    { :ok, message } = receive_message(socket)
    assert message == ":irc.localhost 001 Radar Welcome to the IRC network.\r\n"
    { :ok, message } = receive_message(socket)
    assert message == ":irc.localhost 002 Radar Your host is exIRC, running version 0.0.1.\r\n"
    { :ok, message } = receive_message(socket)
    assert message == ":irc.localhost 003 Radar exIRC 0.0.1 +i +int\r\n"
    { :ok, message } = receive_message(socket)
    assert message == ":irc.localhost 422 :MOTD File is missing\r\n"
  end
end

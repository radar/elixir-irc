defmodule IRCEventTest do
  use ExUnit.Case
  import SocketHelpers

  setup do
     :application.stop(:irc)
     :ok = :application.start(:irc)
   end

  setup do
    opts = [:binary, packet: :line, active: false]
    {:ok, socket} = :gen_tcp.connect('localhost', 6667, opts)
    send_message(socket, "NICK Radar")
    send_message(socket, "USER textual 0 * :Textual User")
    Enum.each(1..4, fn (x) -> receive_message(socket) end)

    {:ok, socket: socket}
  end

  test "joining a channel", %{socket: socket} do
    send_message(socket, "JOIN #railscamp")
    { :ok, message } = receive_message(socket)
    assert message == ":Radar!~textual@localhost JOIN #railscamp\r\n"
  end

  test "cannot send to channel if not joined", %{socket: socket} do
    send_message(socket, "PRIVMSG #railscamp :Hello")
    { :ok, message } = receive_message(socket)
    assert message == ":irc.localhost 404 Radar #railscamp :Cannot send to channel\r\n"
  end
end

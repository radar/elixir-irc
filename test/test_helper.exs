ExUnit.start()

defmodule SocketHelpers do
  def send_message(socket, message) do
    :gen_tcp.send(socket, "#{message}\r\n")
  end

  def receive_message(socket) do
    :gen_tcp.recv(socket, 0, 1000)
  end
end


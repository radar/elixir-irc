defmodule IRC.Client do
  def connect(server \\ "127.0.0.1", port \\ 6667) do
    case :gen_tcp.connect(:erlang.binary_to_list(server), port, [:binary, {:active, false}]) do
      { :ok, socket } ->
        :gen_tcp.send(socket, "NICK Radar \r\n")
        listen(socket)
      { :error, error } ->
        IO.puts "Error: Could not connect to server: #{error}"
        System.halt(1)
    end
  end

  defp listen(socket) do
    case :gen_tcp.recv(socket, 0) do
      { :ok, data } ->
        IO.puts "Received data from servers!"
        IO.puts data
        listen(socket)
      { :error, :closed } ->
        IO.puts "Lost connection to server"
        System.halt(1)
    end
  end
end

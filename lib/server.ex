defmodule IRC.Server do
  use GenEvent

  def start(port \\ 6667) do
    { :ok, event_pid } = GenEvent.start_link()
    GenEvent.add_handler(event_pid, IRC.Event, [])

    users = :ets.new(:users, [])
    channels = :ets.new(:channels, [])

    case :gen_tcp.listen(port, [:binary, {:active, false}]) do
      { :ok, l_socket } ->
        
        Task.async(fn -> accept(l_socket, event_pid) end)
        Task.async(fn ->
          IO.puts "IRC Server started up and is now accepting requests."  
        end)
      { :error, :eaddrinuse } ->
        IO.puts "Address already in use"
        System.halt(1)
    end

    IRC.Event.handle_events(event_pid, users, channels)
  end

  defp accept(l_socket, event_pid) do
    { :ok, socket } = :gen_tcp.accept(l_socket)
    Task.async(fn -> listen(socket, event_pid) end)
    accept(l_socket, event_pid)
  end

  defp listen(socket, event_pid) do
    case :gen_tcp.recv(socket, 0) do
      { :ok, data } ->
        IO.puts "<- #{String.strip(data)}"
        String.strip(data) 
          |> String.split("\r\n")
          |> Enum.each(fn (string) -> process(String.split(string, " "), socket, event_pid) end)
        listen(socket, event_pid)
      { :error, :closed } ->
        IO.puts "Connection closed by client."
    end
  end

  defp process([event | parts], socket, event_pid) do
    GenEvent.notify(event_pid, { event, parts, socket })
  end
end


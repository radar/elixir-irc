defmodule IRC.Server do
  use Application

  def start(_type, _args) do

  end

  def accept(port \\ 6667) do
    GenEvent.start_link(name: Events)
    GenEvent.add_handler(Events, IRC.Event, [])

    Agent.start_link(fn -> %{} end, name: Users)
    Agent.start_link(fn -> %{} end, name: Channels)

    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      { :ok, socket } ->
        
        Task.async(fn -> loop_acceptor(socket) end)
        IO.puts "IRC Server started up and is now accepting requests."  

        IRC.Event.handle_events
      { :error, :eaddrinuse } ->
        IO.puts "Address already in use"
        System.halt(1)
    end

  end

  defp loop_acceptor(socket) do
    { :ok, client } = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(IRC.Server.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        IO.inspect "<- #{String.strip(data)}"
        String.strip(data) |> String.split(" ") |> process(client)
        serve(client)
      { :error, :closed } ->
        IO.puts "Connection closed by client."
    end
  end

  defp process([event | parts], client) do
    GenEvent.notify(Events, { event, parts, client })
  end
end


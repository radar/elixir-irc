defmodule IRC.Server do
  import IRC.Event, only: [reply: 2]

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
    {:ok, pid} = Task.Supervisor.start_child(IRC.Server.TaskSupervisor, fn -> initial_serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  # Handles initial connection handshake with USER + NICK messages
  defp initial_serve(client) do
    case :gen_tcp.recv(client, 0) do
      { :ok, data } ->
        Agent.update(Users, fn users -> Dict.put_new(users, client, %{ channels: [] }) end)
        data = String.strip(data) |> String.split(" ")
        case data do
          ["NICK" | nick] ->
            hostname = resolve_hostname(client)
            Agent.update(Users, fn users ->
              user_data = users[client]
              user_data = Dict.put(user_data, :nick, nick) 
              user_data = Dict.put(user_data, :hostname, hostname) 
              Dict.put(users, client, user_data)
            end)
          ["USER", username, _mode, _ | real_name_parts] ->
            Agent.update(Users, fn users -> 
              user_data = users[client]
              user_data = Dict.put(user_data, :username, username) 
              user_data = Dict.put(user_data, :real_name, Enum.join(real_name_parts, " "))
              Dict.put(users, client, user_data) 
            end)
          other -> IO.inspect("Received unknown message: #{Enum.join(other, "")}")
        end

        user = Agent.get(Users, fn users -> users[client] end)
        case user do
          %{nick: nick, hostname: _, username: _, real_name: _ } ->
            # User has connected and sent through NICK + USER messages.
            # It's showtime!
            welcome(client, nick)
            serve(client)
          _ ->
            # User has not sent through all the right messages yet.
            # Keep listening!
            initial_serve(client)
        end

      { :error, :closed } ->
        IO.puts "Connection closed by client."
    end
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

  defp resolve_hostname(client) do
    {:ok, {ip, _port}} = :inet.peername(client)
    case :inet.gethostbyaddr(ip) do
      { :ok, { :hostent, hostname, _, _, _, _}} ->
        hostname
      { :error, _error } -> 
        IO.puts "Could not resolve hostname for #{ip}. Using IP instead."
        Enum.join(Tuple.to_list(ip), ".")
    end
  end

  defp welcome(client, nick) do
    reply(client, ":irc.localhost 001 #{nick} Welcome to the IRC network.")
    reply(client, ":irc.localhost 002 #{nick} Your host is exIRC, running version 0.0.1.")
    reply(client, ":irc.localhost 003 #{nick} exIRC 0.0.1 +i +int")
    reply(client, ":irc.localhost 422 :MOTD File is missing")
  end


  defp process([event | parts], client) do
    GenEvent.notify(Events, { event, parts, client })
  end

end


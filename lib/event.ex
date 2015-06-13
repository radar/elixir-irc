defmodule IRC.Event do
  use GenEvent

  def handle_event({ event, parts, socket }, messages) do
    { :ok, [{event, parts, socket} | messages ]}
  end

  def handle_call(:messages, messages) do
    { :ok, messages, [] }
  end

  def handle_events(pid, users, channels) do
    stream = GenEvent.stream(pid)
    for event <- stream do
      case event do
        { "NICK", [nick], socket } ->
          handle_nick(socket, users, nick)
        { "USER", [username, mode, _ | real_name_parts], socket } ->
          handle_user(socket, users, username, mode, real_name_parts)
        { "CAP" , [whatever], socket } ->
          handle_cap(socket, whatever)
        { "JOIN", [channel], socket } ->
          handle_join(socket, users, channels, channel)
        { "PART", [channel | part_message], socket } ->
          handle_part(socket, users, channels, channel, part_message)
        { "MODE", [channel], socket } ->
          handle_mode(socket, channels, channel)
        { "PRIVMSG", [channel | parts ], socket } ->
          handle_privmsg(socket, users, channels, channel, parts)
        { "WHO", [channel], socket } ->
          handle_who(socket, channel)
        { "QUIT", parts, socket } ->
          handle_quit(socket, users, parts)
        _ ->
          IO.puts "Unhandled event!"
          IO.inspect(event)
      end
    end
  end

  defp handle_nick(socket, users, nick) do
    {:ok, {ip, _port}} = :inet.peername(socket)
    case :inet.gethostbyaddr(ip) do
      { :ok, { :hostent, hostname, _, _, _, _}} ->
        :ets.insert(users, { socket, %{nick: nick, hostname: hostname }})
      { :error, _error } -> 
        ip = Enum.join(Tuple.to_list(ip), ".")
        IO.puts "Could not resolve hostname for #{ip}. Using IP instead."
        :ets.insert(users, { socket, %{nick: nick, hostname: ip }})
    end
  end

  defp handle_user(socket, users, username, _mode, real_name_parts) do
    user = lookup(users, socket)
    user = Dict.put_new(user, :username, username)
    user = Dict.put_new(user, :real_name, Enum.join(real_name_parts))
    :ets.insert(users, { socket, user })
    nick = user.nick
    reply(socket, ":irc.localhost 001 #{nick} Welcome to the IRC network.")
    reply(socket, ":irc.localhost 002 #{nick} Your host is exIRC, running version 0.0.1.")
    reply(socket, ":irc.localhost 003 #{nick} exIRC 0.0.1 +i +int")
    reply(socket, ":irc.localhost 422 :MOTD File is missing")
  end

  defp handle_cap(_socket, _msg) do
    # TODO: WTF is CAP?
  end

  # REALITY:
  # < :helpa-test!~helpa-tes@1.149.169.255 JOIN #logga
  # << :wilhelm.freenode.net 353 helpa-test = #logga :helpa-test helpa Radar
  # << :wilhelm.freenode.net 366 helpa-test #logga :End of /NAMES list.

  # This program:
  # -> :Radar!~textual@localhost JOIN #logga
  # -> :irc.localhost 332 #logga :this is a topic and it is a grand topic
  # -> :irc.localhost 353 Radar = #logga :Radar
  # -> :irc.localhost 366 Radar #logga :End of /NAMES list.

  defp handle_join(socket, users, channels, channel) do
    user = lookup(users, socket)
    ident = ident_for(user)

    # Attempt to create the channel if it doesn't exist already.
    :ets.insert_new(channels, { channel, %{users: []} })
    [{ _key, channel_data }] = :ets.lookup(channels, channel)
    # User has joined channel, so add them to the list.
    users = [ socket | channel_data.users ]
    channel_data = Dict.put(channel_data, :users, users)
    :ets.insert(channels, { channel, channel_data })

    Enum.each(users, fn (user) ->
      reply(user, "#{ident} JOIN #{channel}")
    end)

    # Show the topic
    reply(socket, ":irc.localhost 332 #{channel} :this is a topic and it is a grand topic")
    # And a list of names
    reply(socket, ":irc.localhost 353 #{user.nick} = #{channel} Radar NotRadar")
    reply(socket, ":irc.localhost 366 #{user.nick} #{channel} :End of /NAMES list.")
  end

  defp handle_part(socket, users, channels, channel, part_message) do
    user = lookup(users, socket)
    ident = ident_for(user)

    [{ _key, channel_data }] = :ets.lookup(channels, channel)

    part_message = Enum.join(part_message, " ")
    Enum.each(channel_data.users, fn (user) ->
      reply(user, "#{ident} PART #{channel} #{part_message}")
    end)

    # User has left the channel, so delete them from list.
    users = Enum.reject(channel_data.users, fn (user) -> user == socket end)
    channel_data = Dict.put(channel_data, :users, users)
    :ets.insert(channels, { channel, channel_data })
  end

  defp handle_mode(_socket, _channels, _channel) do
    # TODO
  end

  defp handle_privmsg(socket, users, channels, channel, parts) do
    [{ _key, channel_data }] = :ets.lookup(channels, channel)
    [{ _key, user_data }] = :ets.lookup(users, socket)
    ident = ident_for(user_data)
    message = Enum.join(parts, " ") #|> String.slice(1..-1)
    Enum.each channel_data.users, fn (user) ->
      unless user == socket do
        reply(user, "#{ident} PRIVMSG #{channel} #{message}")
      end
    end
  end

  def handle_ping(socket) do
    reply(socket, ":irc.localhost PONG")
  end

  def handle_who(_socket, _channel) do
    # TODO: implement
    # The IRC spec isn't helpful for this
    # Probably best to check with a real IRC server and see its response to this command
  end

  def handle_quit(socket, users, _parts) do
    # TODO: Broadcast quit message from _parts to all channels(?) the user is a part of
    :ets.delete(users, socket)
    # Commented out because it crashes the server!
    # socket.close
  end

  defp reply(socket, msg) do
    IO.puts("-> #{msg}")
    :gen_tcp.send(socket, "#{msg} \r\n")
  end

  defp lookup(users, socket) do
    [{ _key, data }] = :ets.lookup(users, socket)
    data
  end

  defp ident_for(user) do
    username = String.slice(user.username, 0..7)
    ":#{user.nick}!~#{username}@#{user.hostname}"
  end
end

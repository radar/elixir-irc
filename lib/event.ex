defmodule IRC.Event do
  use GenEvent

  def handle_event({ event, parts, client }, messages) do
    { :ok, [{event, parts, client} | messages ]}
  end

  def handle_call(:messages, messages) do
    { :ok, messages, [] }
  end

  def handle_events do
    stream = GenEvent.stream(Events)
    for event <- stream do
      case event do
        { "NICK", [nick], client } ->
          handle_nick(client, nick)
        { "CAP" , [whatever], client } ->
          handle_cap(client, whatever)
        { "JOIN", [channel], client } ->
          handle_join(client, channel)
        { "PART", [channel | part_message], client } ->
          handle_part(client, channel, part_message)
        { "MODE", [channel], client } ->
          handle_mode(client, channel)
        { "PRIVMSG", [channel | parts ], client } ->
          handle_privmsg(client, channel, parts)
        { "WHO", [channel], client } ->
          handle_who(client, channel)
        { "QUIT", parts, client } ->
          handle_quit(client, ["QUIT" | parts])
        { "KICK", [channel | parts], client } ->
          handle_kick(client, channel, parts)
        _ ->
          IO.puts "Unhandled event!"
          IO.inspect(event)
      end
    end
  end

  def reply(client, msg) do
    IO.puts("-> #{msg}")
    :gen_tcp.send(client, "#{msg}\r\n")
  end

  defp handle_nick(client, nick) do
    event_user = lookup_user(client)
    # Need to set ident here, as the reply needs to contain old nick
    ident = event_user |> ident_for
    Agent.update(Users, fn users -> Dict.put(users[client], :nick, nick) end)
    msg = "#{ident} NICK #{nick}"
    mass_broadcast_for(event_user, msg)
  end

  defp handle_cap(_socket, _msg) do
    # TODO: WTF is CAP?
  end

  defp handle_join(client, channel) do
    user = lookup_user(client)
    ident = ident_for(user)

    # TODO: Should probably add a list of channels to the user too
    # This is so we can notify their channels when they quit
    # Oh, and when they change nicks we'll need to notify the channels too

    # Attempt to create the channel if it doesn't exist already.
    Agent.update(Channels, fn channels -> Dict.put_new(channels, channel, %{users: []}) end)
    channel_data = Agent.get(Channels, fn channels -> channels[channel] end)
    # User has joined channel, so add them to the list.
    channel_users = [ client | channel_data.users ]
    channel_data = Dict.put(channel_data, :users, channel_users)
    Agent.update(Channels, fn channels -> Dict.put(channels, channel, channel_data) end)

    # Add this channel to the list of channels for the user
    user = Dict.put(user, :channels, [ channel | user.channels ])
    Agent.update(Users, fn users -> Dict.put(users, client, user) end)

    channel_broadcast(channel_users, "#{ident} JOIN #{channel}")

    # Show the topic
    reply(client, ":irc.localhost 332 #{user.nick} #{channel} :this is a topic and it is a grand topic")
    # And a list of names
    names = channel_data.users
      |> Enum.map(fn (user) -> lookup_user(user).nick end)
      |> Enum.join(" ")
    reply(client, ":irc.localhost 353 #{user.nick} = #{channel} :#{names}")
    reply(client, ":irc.localhost 366 #{user.nick} #{channel} :End of /NAMES list.")
  end

  defp handle_part(client, channel, part_message) do
    user = lookup_user(client)
    ident = ident_for(user)

    channel_data = Agent.get(Channels, fn channels -> channels[channel] end)

    part_message = Enum.join(part_message, " ")
    channel_broadcast(channel_data.users, "#{ident} PART #{channel} #{part_message}")

    # User has left the channel, so delete them from list.
    users = Enum.reject(channel_data.users, fn (user) -> user == client end)
    channel_data = Dict.put(channel_data, :users, users)
    Agent.update(Channels, fn channels -> Dict.put(channels, channel, channel_data) end)
  end

  defp handle_mode(_socket, _channel) do
    # TODO
  end

  defp handle_privmsg(client, channel, parts) do
    channel_data = lookup_channel(channel)
    user = lookup_user(client)
    ident = ident_for(user)
    message = Enum.join(parts, " ") #|> String.slice(1..-1)
    users = Enum.reject(channel_data.users, fn (user) -> user == client end)
    channel_broadcast(users, "#{ident} PRIVMSG #{channel} #{message}")
  end

  defp handle_kick(client, channel, parts) do
    channel_data = lookup_channel(channel)
    user = lookup_user(client)
    msg = "#{ident_for(user)} KICK #{channel} #{Enum.join(parts, " ")}"
    users = Enum.reject(channel_data.users, fn (user) -> user == client end)
    channel_broadcast(users, msg)
  end

  defp handle_who(_socket, _channel) do
    # TODO: implement
    # The IRC spec isn't helpful for this
    # Probably best to check with a real IRC server and see its response to this command
  end

  defp handle_quit(client, parts) do
    user = lookup_user(client)
    msg = "#{ident_for(user)} #{Enum.join(parts, " ")}"
    mass_broadcast_for(user, msg)
    # TODO: Remove user from all channels they're a part of
    Agent.update(Users, fn users -> Dict.delete(users, client) end)
    # Commented out because it crashes the server!
    # client.close
  end

  # Used to broadcast events like QUIT or NICK.
  defp mass_broadcast_for(event_user, msg) do
    event_user.channels
      |> Enum.each(
        fn (channel) ->
          Enum.each(lookup_channel(channel).users, fn (user) ->
            reply(user, msg)
          end)
        end
      )
  end

  defp channel_broadcast(users, message) do
    Enum.each users, fn (user) ->
      reply(user, message)
    end
  end

  defp ident_for(user) do
    username = String.slice(user.username, 0..7)
    ":#{user.nick}!~#{username}@#{user.hostname}"
  end

  defp lookup_user(client) do
    Agent.get(Users, fn users -> users[client] end)
  end

  defp lookup_channel(channel) do
    Agent.get(Channels, fn channels -> channels[channel] end)
  end
end

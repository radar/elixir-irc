# IRC

An extremely naive implementation of an IRC server.

I started learning Elixir a week ago and after reading through Programming Elixir I thought I would give creating an IRC server a go. This is because I understand the protocol well enough and it's pretty simple.

The IRC server can be run with:

    mix run -e "IRC.Server.start"

## "Architecture"

Because I am new to Elixir, this repo is littered with _at least_ a thousand mistakes and therefore should not be considered to be a "production ready" IRC server. The server itself isn't even an OTP app and so when it falls over, it falls over **hard**.

In the server I use GenEvent for catching specific events and then handling them. Check out the `IRC.Event` library for that. I also use `:ets` with absolutely no clue if this is the "right way" to do things. `:ets` is used to store the users who are currently connected to the server, as well as information about channels.

There's also a liberal splattering of `Task.async` throughout becuase I couldn't figure out how to get this to listen to more than one connection without it. It seems to work.

Naive connection implementation is probably my "favourite" part. What really should happen is that the connection should wait first for both the `USER` and `NICK` messages (which can arrive in any order). Once it receives those, it opens up a new listening socket that captures the proper events. I tried doing that, but I got vague argument errors which were probably because I was trying to access an `:ets` table in a async Task, but I am not sure.

There's some methods in `IRC.Event` which have `TODO`s attached to them. This is because the IRC spec was written a long time ago with people with as much clue about specs as I have on Elixir. Therefore it's hard to know what I should be sending back for some of the messages.

## TODO

* How to make this an OTP application?
* Should it be an OTP application?
* Exiting the program doesn't stop server from listening on 6667. How do I fix this?
* Was `:ets` the right choice?
* Remove duplication in `handle_nick` message wrt to `nick` and `channels` fields.




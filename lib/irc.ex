defmodule IRC do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Task.Supervisor, [[name: IRC.Server.TaskSupervisor]]),
      worker(Task, [IRC.Server, :accept, [6667]])
    ]

    opts = [strategy: :one_for_one, name: IRC.Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

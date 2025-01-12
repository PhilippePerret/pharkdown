defmodule EssaiUse.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EssaiUseWeb.Telemetry,
      EssaiUse.Repo,
      {DNSCluster, query: Application.get_env(:essai_use, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: EssaiUse.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: EssaiUse.Finch},
      # Start a worker by calling: EssaiUse.Worker.start_link(arg)
      # {EssaiUse.Worker, arg},
      # Start to serve requests, typically the last entry
      EssaiUseWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EssaiUse.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EssaiUseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

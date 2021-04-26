defmodule Ueberauth.Strategy.Auth0.OAuth do
  @moduledoc """
  An implementation of OAuth2 for Auth0.
  To add your `domain`, `client_id` and `client_secret` include these values in your configuration.
      config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
        domain: System.get_env("AUTH0_DOMAIN"),
        client_id: System.get_env("AUTH0_CLIENT_ID"),
        client_secret: System.get_env("AUTH0_CLIENT_SECRET")

  Alternatively, if you need to setup config without needing to recompile, do the following.
      config :ueberauth, Ueberauth.Strategy.Auth0.OAuth,
        domain: {:system, "AUTH0_DOMAIN"},
        client_id: {:system, "AUTH0_CLIENT_ID"},
        client_secret: {:system, "AUTH0_CLIENT_SECRET"}

  The JSON serializer used is the same as `Ueberauth` so if you need to
  customize it, you can configure it in the `Ueberauth` configuration:

      config :ueberauth, Ueberauth,
        json_library: Poison # Defaults to Jason

  """
  use OAuth2.Strategy
  alias OAuth2.Client
  alias OAuth2.Strategy.AuthCode

  def options(conn, otp_app) do
    configs = Application.get_env(otp_app || :ueberauth, Ueberauth.Strategy.Auth0.OAuth)
    configs = compute_configs(conn, configs)

    unless configs do
      raise(
        "Expected to find settings under `config #{inspect(otp_app)}, Ueberauth.Strategy.Auth0.OAuth`, " <>
          "got nil. Check your config.exs."
      )
    end

    domain = get_config_value(configs[:domain])
    client_id = get_config_value(configs[:client_id])
    client_secret = get_config_value(configs[:client_secret])

    serializers = %{
      "application/json" => Ueberauth.json_library(otp_app)
    }

    opts = [
      strategy: __MODULE__,
      site: "https://#{domain}",
      authorize_url: "https://#{domain}/authorize",
      token_url: "https://#{domain}/oauth/token",
      userinfo_url: "https://#{domain}/userinfo",
      client_id: client_id,
      client_secret: client_secret,
      serializers: serializers
    ]

    Keyword.merge(configs, opts)
  end

  @doc """
  Construct a client for requests to Auth0.
  Optionally include any OAuth2 options here to be merged with the defaults.
      Ueberauth.Strategy.Auth0.OAuth.client(redirect_uri: "http://localhost:4000/auth/auth0/callback")
  This will be setup automatically for you in `Ueberauth.Strategy.Auth0`.
  These options are only useful for usage outside the normal callback phase of Ueberauth.
  """
  def client(conn, opts \\ []) do
    otp_app = Keyword.get(opts, :otp_app)

    conn
    |> options(otp_app)
    |> Keyword.merge(opts)
    |> Client.new
  end

  @doc """
  Provides the authorize url for the request phase of Ueberauth. No need to call this usually.
  """
  def authorize_url!(conn, params \\ [], opts \\ []) do
    conn
    |> client(opts)
    |> Client.authorize_url!(params)
  end

  def get_token!(conn, params \\ [], opts \\ []) do
    otp_app = Keyword.get(opts, :otp_app)

    client_secret =
      conn
      |> options(otp_app)
      |> Keyword.get(:client_secret)

    params = Keyword.merge(params, client_secret: client_secret)
    headers = Keyword.get(opts, :headers, [])
    opts = Keyword.get(opts, :options, [])

    client_options =
      opts
      |> Keyword.get(:client_options, [])
      |> Keyword.merge(otp_app: otp_app)

    Client.get_token(client(client_options), params, headers, opts)
  end

  # Strategy Callbacks

  def authorize_url(client, params) do
    AuthCode.authorize_url(client, params)
  end

  def get_token(client, params, headers) do
    client
    |> put_header("Accept", "application/json")
    |> AuthCode.get_token(params, headers)
  end

  defp get_config_value({:system, value}), do: System.get_env(value)
  defp get_config_value(value), do: value

  defp compute_configs(conn, configs) do
    case conn do
      %Plug.Conn{} = conn ->
        with module when is_atom(module) <- Keyword.get(configs, :config_from),
             true <- function_exported?(module, :get_domain, 1),
             true <- function_exported?(module, :get_client_id, 1),
             true <- function_exported?(module, :get_client_secret, 1)
        do
          configs |> Keyword.merge([
            domain: apply(module, :get_domain, [conn]),
            client_id: apply(module, :get_client_id, [conn]),
            client_secret: apply(module, :get_client_secret, [conn])
          ])
        else
          _ -> configs
        end
      _ ->
        configs
    end
  end
end

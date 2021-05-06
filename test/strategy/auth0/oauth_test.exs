defmodule Ueberauth.Strategy.Auth0.OAuthTest do
  use ExUnit.Case

  import Ueberauth.Strategy.Auth0.OAuth, only: [client: 0, client: 1]

  @test_domain "example-app.auth0.com"

  describe "when default configurations are used" do
    setup do
      {:ok, %{client: client()}}
    end

    test "creates correct client", %{client: client} do
      asserts_client_creation(client)
    end

    test "raises when there is no configuration" do
      assert_raise(RuntimeError, ~r/^Expected to find settings under.*/, fn ->
        client(otp_app: :unknown_auth0_otp_app)
      end)
    end
  end

  describe "when custom/computed configurations are used" do
    setup do
      Mix.Config.read!("test/support/config_from.ex")
      {:ok, %{client: client()}}
    end

    test "creates correct client", %{client: client} do
      asserts_client_creation(client)
    end

    test "raises when there is no configuration" do
      assert_raise(RuntimeError, ~r/^Expected to find settings under.*/, fn ->
        client(otp_app: :unknown_auth0_otp_app)
      end)
    end
  end

  defp asserts_client_creation(client) do
    assert client.client_id == "clientidsomethingrandom"
    assert client.client_secret == "clientsecret-somethingsecret"
    assert client.redirect_uri == ""
    assert client.strategy == Ueberauth.Strategy.Auth0.OAuth
    assert client.authorize_url == "https://#{@test_domain}/authorize"
    assert client.token_url == "https://#{@test_domain}/oauth/token"
    assert client.site == "https://#{@test_domain}"
  end
end

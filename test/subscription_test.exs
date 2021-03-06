defmodule Poxa.SubscriptionTest do
  use ExUnit.Case
  alias Poxa.AuthSignature
  alias Poxa.PresenceSubscription
  alias Poxa.Channel
  import :meck
  import Poxa.Subscription

  setup do
    new PresenceSubscription
    new AuthSignature
    new Channel, [:passthrough]
    new :gproc
    on_exit fn -> unload end
    :ok
  end

  test "subscription to a public channel" do
    expect(Channel, :subscribed?, 2, false)
    expect(:gproc, :reg, 1, :registered)
    assert subscribe!(%{"channel" => "public-channel"}, nil) == {:ok, "public-channel"}
    assert validate :gproc
  end

  test "subscription to a missing channel name" do
    assert subscribe!(%{}, nil) == :error
  end

  test "subscription to a public channel but already subscribed" do
    expect(Channel, :subscribed?, 2, true)
    assert subscribe!(%{"channel" => "public-channel"}, nil) == {:ok, "public-channel"}
  end

  test "subscription to a private channel" do
    expect(Channel, :subscribed?, 2, false)
    expect(:gproc, :reg, 1, :registered)
    expect(AuthSignature, :validate, 2, :ok)
    assert subscribe!(%{"channel" => "private-channel",
                        "auth" => "signeddata" }, "SocketId") == {:ok, "private-channel"}
    assert validate AuthSignature
    assert validate :gproc
  end

  test "subscription to a private channel having a channel_data" do
    expect(Channel, :subscribed?, 2, false)
    expect(:gproc, :reg, 1, :registered)
    expect(AuthSignature, :validate, 2, :ok)
    assert subscribe!(%{"channel" => "private-channel",
                        "auth" => "signeddata",
                        "channel_data" => "{\"user_id\" : \"id123\", \"user_info\" : \"info456\"}"}, "SocketId") == {:ok, "private-channel"}
    assert validate AuthSignature
    assert validate :gproc
  end

  test "subscription to a presence channel" do
    expect(Channel, :subscribed?, 2, false)
    expect(:gproc, :lookup_values, 1, :values) # subscribed? returns false
    expect(AuthSignature, :validate, 2, :ok)
    expect(PresenceSubscription, :subscribe!, 2, :ok)

    assert subscribe!(%{"channel" => "presence-channel",
                        "auth" => "signeddata",
                        "channel_data" => "{\"user_id\" : \"id123\", \"user_info\" : \"info456\""}, "SocketId") == :ok

    assert validate AuthSignature
    assert validate PresenceSubscription
    assert validate :gproc
  end

  test "subscription to a private-channel having bad authentication" do
    expect(AuthSignature, :validate, 2, :error)

    assert subscribe!(%{"channel" => "private-channel",
                        "auth" => "signeddate"}, "SocketId") == :error

    assert validate AuthSignature
  end

  test "subscription to a presence-channel having bad authentication" do
    expect(AuthSignature, :validate, 2, :error)

    assert subscribe!(%{"channel" => "presence-channel",
                        "auth" => "signeddate"}, "SocketId") == :error

    assert validate AuthSignature
  end

  test "unsubscribe channel being subscribed" do
    expect(Channel, :subscribed?, 2, true)
    expect(Channel, :presence?, 1, false)
    expect(:gproc, :unreg, 1, :ok)

    assert unsubscribe!(%{"channel" => "a_channel"}) == {:ok, "a_channel"}

    assert validate :gproc
  end

  test "unsubscribe channel being not subscribed" do
    expect(Channel, :subscribed?, 2, false)
    expect(Channel, :presence?, 1, false)

    assert unsubscribe!(%{"channel" => "a_channel"}) == {:ok, "a_channel"}
  end

  test "unsubscribe from a presence channel" do
    expect(Channel, :subscribed?, 2, false)
    expect(Channel, :presence?, 1, true)
    expect(:gproc, :unreg, 1, :ok)
    expect(PresenceSubscription, :unsubscribe!, 1, {:ok, "presence-channel"})

    assert unsubscribe!(%{"channel" => "presence-channel"}) == {:ok, "presence-channel"}

    assert validate PresenceSubscription
    assert validate :gproc
  end
end

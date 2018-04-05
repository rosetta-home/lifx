defmodule Lifx.API.Websocket do
    require Logger
    alias Lifx.Protocol.HSBK

    def init(req, state) do
        user_id = req
                  |> :cowboy_req.parse_qs()
                  |> Enum.find(&(elem(&1, 0) == "user_id"))
                  |> elem(1)
        Process.send_after(self(), :heartbeat, 1000)
        {:cowboy_websocket, req, [user_id: user_id] ++ state}
    end

    def websocket_init(state) do
        {:ok, state}
    end

    def websocket_terminate(_reason, state) do
        Logger.info "Terminating Websocket #{state.user_id}"
        :ok
    end

    def websocket_handle({:text, data}, state) do
        message = data |> Poison.decode!
        Lifx.Client.set_color(%HSBK{
            :hue => message["h"],
            :saturation => message["s"]*100,
            :brightness => message["l"]*100,
            :kelvin => 4000
        }, 1)
        {:reply, {:text, Poison.encode!(%{:ack => true})}, state}
    end

    def websocket_handle(_data, state) do
        {:ok, state}
    end

    def handle_message(message = %{}, state) do
        IO.inspect message
        Logger.info "Sending to: #{message.id}"
        send(message.id, message)
        state
    end

    def websocket_info(:heartbeat, state) do
        Process.send_after(self(), :heartbeat, 1000)
        {:reply, {:text, Poison.encode!(%{:type => :heartbeat})}, state}
    end

    def websocket_info(_info, state) do
        {:ok, state}
    end

end

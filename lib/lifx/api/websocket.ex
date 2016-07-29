defmodule Lifx.API.Websocket do
    @behaviour :cowboy_websocket_handler
    require Logger
    alias Lifx.Protocol.HSBK

    @node "node"

    defmodule State do
        defstruct [:user_id, nodes: []]
    end

    def init({tcp, http}, _req, _opts) do
        {:upgrade, :protocol, :cowboy_websocket}
    end

    def websocket_init(_TransportName, req, _opts) do
        {user_id, req} = :cowboy_req.qs_val("user_id", req)
        Process.send_after(self, :heartbeat, 1000)
        {:ok, req, %State{user_id: user_id}}
    end

    def websocket_terminate(_reason, _req, state) do
        Logger.info "Terminating Websocket #{state.user_id}"
        Enum.each(state.nodes, fn(id) ->
            h_id = "#{state.user_id}:#{id}"
            Node.remove_event_handler(id, {Handler, id})
        end)
        :ok
    end

    def websocket_handle({:text, data}, req, state) do
        message = data |> Poison.decode!
        Lifx.Client.set_color(%HSBK{
            :hue => message["h"],
            :saturation => message["s"]*100,
            :brightness => message["l"]*100,
            :kelvin => 4000
        }, 1)
        {:reply, {:text, Poison.encode!(%{:ack => true})}, req, state}
    end

    def websocket_handle(_data, req, state) do
        {:ok, req, state}
    end

    def handle_message(message = %{}, state) do
        IO.inspect message
        Logger.info "Sending to: #{message.id}"
        send(message.id, message)
        state
    end

    def websocket_info(:heartbeat, req, state) do
        Process.send_after(self, :heartbeat, 1000)
        {:reply, {:text, Poison.encode!(%{:type => :heartbeat})}, req, state}
    end

    def websocket_info(_info, req, state) do
        {:ok, req, state}
    end

end

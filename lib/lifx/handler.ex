defmodule Lifx.Handler do
    use GenServer
    require Logger
    alias Lifx.Device.State, as: Device

    def init(args) do
        {:ok, args}
    end

    def handle_cast(%Device{} = device, parent) do
        send(parent, device)
        {:noreply, parent}
    end
end

defmodule Lifx.Handler do
    use GenEvent
    require Logger
    alias Lifx.Device.State, as: Device

    def init do
        {:ok, []}
    end

    def handle_event(%Device{} = device, parent) do
        send(parent, device)
        {:ok, parent}
    end
end

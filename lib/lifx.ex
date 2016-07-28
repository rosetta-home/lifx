defmodule Lifx do
    use Application
    require Logger

    defmodule Handler do
        use GenEvent
        require Logger
        alias Lifx.Device.State, as: Device

        def init do
            {:ok, []}
        end

        def handle_event(%Device{} = device, state) do
            Logger.info "New Device found: #{inspect device}"
            {:ok, state}
        end
    end

    def start(_type, _args) do
        Lifx.Supervisor.start_link
    end
end

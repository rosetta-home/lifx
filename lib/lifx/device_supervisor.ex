defmodule Lifx.DeviceSupervisor do
    use Supervisor
    use Lifx.Protocol.Types
    require Logger
    alias Lifx.Protocol.Packet
    alias Lifx.Device.State, as: Device

    def start_link do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
        children = [
            worker(Lifx.Device, [], restart: :transient)
        ]
        supervise(children, strategy: :simple_one_for_one)
    end

    def start_device(%Device{} = device) do
        Logger.info "Starting Device #{inspect device}"
        Supervisor.start_child(__MODULE__, [device])
    end
end

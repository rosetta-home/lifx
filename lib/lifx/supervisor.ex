defmodule Lifx.Supervisor do
    use Supervisor

    @name __MODULE__

    def start_link do
        Supervisor.start_link(__MODULE__, :ok, name: @name)
    end

    def init(:ok) do
        children = [
            worker(Lifx.Client, []),
            worker(Lifx.TCPServer, []),
            supervisor(Task.Supervisor, [[name: Lifx.Client.PacketSupervisor]]),
            supervisor(Lifx.DeviceSupervisor, []),
        ]
        supervise(children, strategy: :one_for_one)
    end
end

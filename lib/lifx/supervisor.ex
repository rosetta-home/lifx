defmodule Lifx.Supervisor do
    use Supervisor

    @tcp_server Application.get_env(:lifx, :tcp_server)

    def start_link do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
        children = [
            worker(Lifx.Client, []),
            supervisor(Task.Supervisor, [[name: Lifx.Client.PacketSupervisor]]),
            supervisor(Lifx.DeviceSupervisor, []),
        ]

        children =
            case @tcp_server do
                true -> [worker(Lifx.TCPServer, []) | children]
                false -> children
            end

        supervise(children, strategy: :one_for_one)
    end
end

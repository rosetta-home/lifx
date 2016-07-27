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
        ]
        supervise(children, strategy: :one_for_one)
    end
end

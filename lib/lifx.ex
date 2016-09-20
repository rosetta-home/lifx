defmodule Lifx do
    use Application
    require Logger

    def start(_type, _args) do
        {:ok, pid} = Lifx.Supervisor.start_link
    end
end

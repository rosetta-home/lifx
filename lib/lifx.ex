defmodule Lifx do
    use Application
    require Logger

    def start(_type, _args) do
        Lifx.Supervisor.start_link
    end
end

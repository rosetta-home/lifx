defmodule Lifx do
    use Application
    require Logger

    defmodule Event do
        defstruct [:type, :value, :id]
    end

    def start(_type, _args) do
        {:ok, pid} = Lifx.Supervisor.start_link
    end
end

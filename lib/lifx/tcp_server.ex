defmodule Lifx.TCPServer do
    alias Lifx.API

    def start_link do
        port =  Application.get_env(:lifx, :tcp_port)
        dispatch = :cowboy_router.compile([
            { :_,
                [
                    {"/", :cowboy_static, {:priv_file, :lifx, "index.html"}},
                    {"/static/[...]", :cowboy_static, {:priv_dir,  :lifx, "static"}},
                    {"/ws", API.Websocket, []},
            ]}
        ])
        {:ok, _} = :cowboy.start_http(:http,
            100,
            [{:port, port}],
            [{:env, [{:dispatch, dispatch}]}]
        )
    end
end

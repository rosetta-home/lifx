defmodule Lifx.Client do
    use GenServer
    use Lifx.Protocol.Types

    alias Lifx.Protocol
    alias Lifx.Protocol.{FrameHeader, FrameAddress, ProtocolHeader}
    alias Lifx.Protocol.{Device, Packet}
    alias Lifx.Protocol.{HSBK}

    @port 56700
    @multicast {255, 255, 255, 255}

    defmodule State do
        defstruct udp: nil,
            source: 0,
            devices: []
    end

    def start_link do
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def discover(client) do
        GenServer.call(client, :discover)
    end

    def set_color(client, %HSBK{} = hsbk, duration \\ 1000) do
        GenServer.call(client, {:set_color, hsbk, duration})
    end

    def init(:ok) do
        udp_options = [
            :binary,
            {:broadcast, true},
            {:ip, {0,0,0,0}},
            {:reuseaddr, true}
        ]
        source = :rand.uniform(4294967295)
        IO.inspect source
        {:ok, udp} = :gen_udp.open(0 , udp_options)
        {:ok, %State{:udp => udp, :source => source}}
    end

    def handle_call({:set_color, %HSBK{} = hsbk, duration}, _from, state) do
        fh = %FrameHeader{:source => state.source}
        fa = %FrameAddress{}
        ph = %ProtocolHeader{:type => @light_setcolor}
        payload = Protocol.create_color(hsbk, duration)
        packet = Protocol.create_packet(fh, fa, ph, payload)
        :gen_udp.send(state.udp, @multicast, @port, packet)
        {:reply, :ok, state}
    end

    def handle_call(:discover, _from, state) do
        b = discover_devices(state.source)
        Base.encode16(b) |> IO.inspect
        :gen_udp.send(state.udp, @multicast, @port, b)
        {:reply, :ok, state}
    end

    def handle_info({:udp, _s, ip, _port, payload}, state) do
        {:noreply, payload
            |> Protocol.parse
            |> IO.inspect
            |> handle_packet(ip, state)
            |> IO.inspect
        }
    end

    def handle_packet(%Packet{:protocol_header => %ProtocolHeader{:type => @stateservice}} = packet, ip, state) do
        d = %Device{:host => ip, :port => packet.payload.port, :id => packet.frame_address.target}
        :gen_udp.send(state.udp, d.host, d.port, get_label(state.source, d.id))
        cond do
            Enum.any?(state.devices, fn(dev) -> dev.id == d.id end) -> state
            true -> %State{state | :devices => [d | state.devices]}
        end
    end

    def handle_packet(%Packet{:protocol_header => %ProtocolHeader{:type => @statelabel}} = packet, _ip, state) do
        id = packet.frame_address.target
        %State{state | :devices => Enum.reduce(state.devices, [], fn(d, acc) ->
            dev =
                cond do
                    d.id == id -> %Device{d | :label => packet.payload.label}
                    true -> d
                end
            [dev | acc]
        end)}
    end

    def handle_packet(%Packet{} = _packet, _ip, state) do
        state
    end

    def get_label(source, id) do
        fh = %FrameHeader{:source => source, :tagged => 0}
        fa = %FrameAddress{:target => id}
        ph = %ProtocolHeader{:type => @getlabel}
        Protocol.create_packet(fh, fa, ph)
    end

    def discover_devices(source) do
        fh = %FrameHeader{:source => source}
        fa = %FrameAddress{}
        ph = %ProtocolHeader{:type => @getservice}
        Protocol.create_packet(fh, fa, ph)
    end

end

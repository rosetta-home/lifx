defmodule LifxClient do
    use GenServer

    @port 56700
    @multicast {255, 255, 255, 255}

    @getservice 2
    @stateservice 3
    @gethostinfo 12
    @statehostinfo 13
    @gethostfirmware 14
    @statehostfirmware 15
    @getwifiinfo 16
    @statewifiinfo 17
    @getwififirmware 18
    @statewififirmware 19
    @getpower 20
    @setpower 21
    @statepower 22
    @getlabel 23
    @setlabel 24
    @statelabel 25
    @getversion 32
    @stateversion 33
    @getinfo 34
    @stateinfo 35
    @getlocation 48
    @statelocation 50
    @getgroup 51
    @stategroup 53
    @acknowledgement 45
    @echorequest 58
    @echoresponse 59
    @light_get 101
    @light_setcolor 102
    @light_state 107
    @light_getpower 116
    @light_setpower 117
    @light_statepower 118

    defmodule State do
        defstruct udp: nil,
            source: 0,
            devices: []
    end

    defmodule Device do
        defstruct host: nil,
            port: nil,
            id: nil,
            label: nil
    end

    defmodule FrameHeader do
        defstruct size: 0,
            origin: 0,
            tagged: 0,
            addressable: 0,
            protocol: 1025,
            source: 0
    end

    defmodule FrameAddress do
        defstruct target: 0,
            reserved: 0,
            reserved1: 0,
            ack_required: 0,
            res_required: 1,
            sequence: 0
    end

    defmodule ProtocolHeader do
        defstruct reserved: 0,
            type: 2,
            reserved1: 0
    end

    defmodule Packet do
        defstruct frame_header: %FrameHeader{},
            frame_address: %FrameAddress{},
            protocol_header: %ProtocolHeader{},
            payload: %{}
    end

    def start_link do
        GenServer.start_link(__MODULE__, :ok)
    end

    def discover(client) do
        GenServer.call(client, :discover)
    end

    def set_color(client, hue \\ 120, saturation \\ 100, brightness \\ 100, kelvin \\ 4000, duration \\ 1000) do
        GenServer.call(client, {:set_color, hue, saturation, brightness, kelvin, duration})
    end

    def init(:ok) do
        udp_options = [
            :binary,
            {:broadcast, true},
            {:ip, {0,0,0,0}},
            {:reuseaddr, true}
        ]
        source = :rand.uniform(4294967295)
        {:ok, udp} = :gen_udp.open(0 , udp_options)
        {:ok, %State{:udp => udp, :source => source}}
    end

    def handle_call({:set_color, hue, saturation, brightness, kelvin, duration}, _from, state) do
        hue = round((65535/360) * hue)
        saturation = round((65535/100) * saturation)
        brightness = round((65535/100) * brightness)
        color = <<
            0::little-integer-size(8),
            hue::little-integer-size(16),
            saturation::little-integer-size(16),
            brightness::little-integer-size(16),
            kelvin::little-integer-size(16),
            duration::little-integer-size(32)
        >>
        fh = %FrameHeader{:source => state.source}
        fa = %FrameAddress{}
        ph = %ProtocolHeader{:type => @light_setcolor}
        packet = create_packet(fh, fa, ph, color)
        :gen_udp.send(state.udp, @multicast, @port, packet)
        {:reply, :ok, state}
    end

    def handle_call(:discover, _from, state) do
        b = discover_devices(state.source)
        parse(b)
        |> IO.inspect
        Base.encode16(b) |> IO.inspect
        :gen_udp.send(state.udp, @multicast, @port, b)
        {:reply, :ok, state}
    end

    def handle_info({:udp, _s, ip, _port, payload}, state) do
        packet = parse(payload)
        IO.inspect packet
        new_state =
            case packet do
                %Packet{:protocol_header => %ProtocolHeader{:type => @stateservice}} ->
                    d = %Device{:host => ip, :port => packet.payload.port, :id => packet.frame_address.target}
                    cond do
                        Enum.any?(state.devices, fn(dev) -> dev.id == d.id end) -> state
                        true -> %State{state | :devices => [d | state.devices]}
                    end
                _ -> state
            end
        IO.inspect(new_state)
        {:noreply, new_state}
    end

    def parse(payload) do
        <<
            size::little-integer-size(16),
            origin::size(2),
            tagged::size(1),
            addressable::size(1),
            protocol::little-integer-size(12),
            source::little-integer-size(32),
            target::size(64),
            reserved::size(48),
            reserved1::size(6),
            ack_required::size(1),
            res_required::size(1),
            sequence::size(8),
            reserved2::size(64),
            type::little-integer-size(16),
            reserved3::size(16),
            rest::binary,
        >> = payload
        fh = %FrameHeader{
            :size => size,
            :origin => origin,
            :tagged => tagged,
            :addressable => addressable,
            :protocol => protocol,
            :source => source,
        }
        fa = %FrameAddress{
            :target => target,
            :reserved => reserved,
            :reserved1 => reserved1,
            :ack_required => ack_required,
            :res_required => res_required,
            :sequence => sequence,
        }
        ph = %ProtocolHeader{
            :reserved => reserved2,
            :type => type,
            :reserved1 => reserved3
        }
        packet = %Packet{
            :frame_header => fh,
            :frame_address => fa,
            :protocol_header => ph,
        }
        parse_payload(packet, rest)
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @stateservice}} = packet, payload) do
        <<
            service::little-integer-size(8),
            port::little-integer-size(32)
        >> = payload
        %Packet{packet | :payload => %{:service => service, :port => port}}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statehostinfo}} = packet, payload) do
        <<
            signal::little-float-size(32),
            tx::little-integer-size(32),
            rx::little-integer-size(32),
            reserved::signed-little-integer-size(16)
        >> = payload
        %Packet{packet | :payload => %{:signal => signal, :tx => tx, :rx => rx, :reserved => reserved}}
    end

    def parse_payload(%Packet{} = packet, _payload) do
        packet
    end

    def discover_devices(source) do
        fh = %FrameHeader{:source => source}
        fa = %FrameAddress{}
        ph = %ProtocolHeader{:type => @getservice}
        create_packet(fh, fa, ph)
    end

    def create_packet(%FrameHeader{} = fh, %FrameAddress{} = fa, %ProtocolHeader{} = ph, payload \\ <<>>) when is_binary(payload) do
        packet = <<
            fh.origin::size(2),
            fh.tagged::size(1),
            fh.addressable::size(1),
            fh.protocol::little-integer-size(12),
            fh.source::little-integer-size(32)
        >> <> <<
            fa.target::size(64),
            fa.reserved::size(48),
            fa.reserved1::size(6),
            fa.ack_required::size(1),
            fa.res_required::size(1),
            fa.sequence::size(8),
        >> <> <<
            ph.reserved::size(64),
            ph.type::little-integer-size(16),
            ph.reserved1::size(16),
        >> <> payload
        <<byte_size(packet)+2::little-integer-size(16)>> <> packet
    end

end

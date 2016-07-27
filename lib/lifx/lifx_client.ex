defmodule Lifx.Client do
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
            tagged: 1,
            addressable: 1,
            protocol: 1024,
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
        GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def discover(client) do
        GenServer.call(client, :discover)
    end

    def set_color(client, hue \\ 120, saturation \\ 100, brightness \\ 100, kelvin \\ 4000, duration \\ 1000) do
        GenServer.call(client, {:set_color, hue, saturation, brightness, kelvin, duration})
    end

    def test(client) do
        GenServer.call(client, :test)
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

    def handle_call(:test, _from, state) do
        data = "24000034f238258300000000000000000000000000000100000000000000000002000000"
        data2 = "29000054f2382583d073d512bcb900004c49465856320000c83d59844837651403000000017cdd0000"
        {:ok, bin} = Base.decode16(data, case: :lower)
        IO.inspect byte_size(bin)
        {:ok, bin2} = Base.decode16(data2, case: :lower)
        IO.inspect byte_size(bin2)
        parse(bin) |> IO.inspect
        parse(bin2) |> IO.inspect
        {:reply, :ok, state}
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
        Base.encode16(b) |> IO.inspect
        :gen_udp.send(state.udp, @multicast, @port, b)
        {:reply, :ok, state}
    end

    def handle_info({:udp, _s, ip, _port, payload}, state) do
        packet = parse(payload)
        IO.inspect packet
        new_state = handle_packet(packet, ip, state)
        IO.inspect(new_state)
        {:noreply, new_state}
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
        create_packet(fh, fa, ph)
    end

    def discover_devices(source) do
        fh = %FrameHeader{:source => source}
        fa = %FrameAddress{}
        ph = %ProtocolHeader{:type => @getservice}
        create_packet(fh, fa, ph)
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

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statelabel}} = packet, payload) do
        << label::bytes-size(32) >> = payload
        %Packet{packet | :payload => %{:label => String.rstrip(label, 0)}}
    end

    def parse_payload(%Packet{} = packet, _payload) do
        packet
    end

    def parse(payload) do
        <<
            size::little-integer-size(16),
            otap::bits-size(16),
            source::little-integer-size(32),

            target::little-integer-size(64),
            rar::bits-size(8),
            sequence::little-integer-size(8),
            reserved1::little-integer-size(48),

            reserved3::little-integer-size(64),
            type::little-integer-size(16),
            reserved4::little-integer-size(16),
            rest::binary,
        >> = payload
        <<
            origin::size(2),
            tagged::size(1),
            addressable::size(1),
            protocol::size(12)
        >> = reverse_bits(otap)
        <<
            reserved2::size(6),
            ack_required::size(1),
            res_required::size(1),
        >> = reverse_bits(rar)
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
            :reserved => reserved1,
            :reserved1 => reserved2,
            :ack_required => ack_required,
            :res_required => res_required,
            :sequence => sequence,
        }
        ph = %ProtocolHeader{
            :reserved => reserved3,
            :type => type,
            :reserved1 => reserved4
        }
        packet = %Packet{
            :frame_header => fh,
            :frame_address => fa,
            :protocol_header => ph,
        }
        parse_payload(packet, rest)
    end

    def create_packet(%FrameHeader{} = fh, %FrameAddress{} = fa, %ProtocolHeader{} = ph, payload \\ <<>>) when is_binary(payload) do
        otap = reverse_bits(<<fh.origin::size(2),
            fh.tagged::size(1),
            fh.addressable::size(1),
            fh.protocol::size(12),
        >>)
        rar = reverse_bits(<<
            fa.reserved1::size(6),
            fa.ack_required::size(1),
            fa.res_required::size(1),
        >>)
        packet = <<
            otap::bits-size(16),
            fh.source::little-integer-size(32),

            fa.target::little-integer-size(64),
            fa.reserved::little-integer-size(48),
            rar::bits-size(8),
            fa.sequence::little-integer-size(8),

            ph.reserved::little-integer-size(64),
            ph.type::little-integer-size(16),
            ph.reserved1::little-integer-size(16),
        >> <> payload
        <<byte_size(packet)+2::little-integer-size(16)>> <> packet
    end

    def reverse_bits(bits) do
        bits
        |> :erlang.binary_to_list
        |> :lists.reverse
        |> :erlang.list_to_binary
    end

end
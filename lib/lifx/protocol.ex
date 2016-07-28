defmodule Lifx.Protocol do
    use Lifx.Protocol.Types

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
            reserved: 000000,
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

    defmodule HSBK do
        defstruct [hue: 120,
            saturation: 100,
            brightness: 100,
            kelvin: 4000]

        def hue(hsbk) do
            round((65535/360) * hsbk.hue)
        end

        def saturation(hsbk) do
            round((65535/100) * hsbk.saturation)
        end

        def brightness(hsbk) do
            round((65535/100) * hsbk.brightness)
        end

        def kelvin(hsbk) do
            hsbk.kelvin
        end
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

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @light_state}} = packet, payload) do
        <<
            hsbk::bits-size(64),
            reserved::signed-little-size(16),
            power::little-size(16),
            label::bytes-size(32),
            reserved1::little-size(64),
        >> = payload
        %Packet{packet | :payload => %{
            :hsbk => parse_color(hsbk),
            :reserved => reserved,
            :power => power,
            :label => parse_label(label),
            :reserved1 => reserved1
        }}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statelabel}} = packet, payload) do
        %Packet{packet | :payload => %{:label => parse_label(payload)}}
    end

    def parse_payload(%Packet{} = packet, _payload) do
        packet
    end

    def create_label(label) do
        << label::bytes-size(32) >>
    end

    def parse_label(payload) do
        << label::bytes-size(32) >> = payload
        String.rstrip(label, 0)
    end

    def create_color(%HSBK{} = hsbk, duration) do
        <<
            0::little-integer-size(8),
            HSBK.hue(hsbk)::little-integer-size(16),
            HSBK.saturation(hsbk)::little-integer-size(16),
            HSBK.brightness(hsbk)::little-integer-size(16),
            HSBK.kelvin(hsbk)::little-integer-size(16),
            duration::little-integer-size(32)
        >>
    end

    def parse_color(payload) do
        <<
            hue::little-integer-size(16),
            saturation::little-integer-size(16),
            brightness::little-integer-size(16),
            kelvin::little-integer-size(16),
        >> = payload
        %HSBK{:hue => hue, :saturation => saturation, :brightness => brightness, :kelvin => kelvin}
    end

    def parse(payload) do
        <<
            size::little-integer-size(16),
            otap::bits-size(16),
            source::little-integer-size(32),

            target::little-integer-size(64),
            reserved1::little-integer-size(48),
            rar::bits-size(8),
            sequence::little-integer-size(8),

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
        >>
        <<byte_size(packet)+2::little-integer-size(16)>> <> packet <> payload
    end

    def reverse_bits(bits) do
        bits
        |> :erlang.binary_to_list
        |> :lists.reverse
        |> :erlang.list_to_binary
    end
end

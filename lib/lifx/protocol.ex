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
            tagged: 0,
            addressable: 1,
            protocol: 1024,
            source: 0
    end

    defmodule FrameAddress do
        defstruct target: 0,
            reserved: 000000,
            reserved1: 0,
            ack_required: 0,
            res_required: 0,
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

    defmodule Group do
        defstruct id: [],
            label: nil,
            updated_at: 0
    end

    defmodule Location do
        defstruct id: [],
            label: nil,
            updated_at: 0
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
            :hsbk => parse_hsbk(hsbk),
            :reserved => reserved,
            :power => power,
            :label => parse_label(label),
            :reserved1 => reserved1
        }}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statelabel}} = packet, payload) do
        %Packet{packet | :payload => %{:label => parse_label(payload)}}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statepower}} = packet, payload) do
        << level::size(16) >> = payload
        %Packet{packet | :payload => %{:level => level}}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @stategroup}} = packet, payload) do
        <<
            id::bytes-size(16),
            label::bytes-size(32),
            updated_at::size(64)
        >> = payload
        %Packet{packet | :payload => %{
            :group => %Group{
                :id => id,
                :label => parse_label(label),
                :updated_at => updated_at
            }
        }}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statelocation}} = packet, payload) do
        <<
            id::bytes-size(16),
            label::bytes-size(32),
            updated_at::size(64)
        >> = payload
        %Packet{packet | :payload => %{
            :location => %Location{
                :id => id,
                :label => parse_label(label),
                :updated_at => updated_at
            }
        }}
    end

    def parse_payload(%Packet{:protocol_header => %ProtocolHeader{:type => @statewifiinfo}} = packet, payload) do
        <<
            signal::little-float-size(32),
            rx::little-size(32),
            tx::little-size(32),
            reserved::signed-little-size(16)
        >> = payload
        %Packet{packet | :payload => %{
            :signal => signal,
            :rx => rx,
            :tx => tx,
            :reserved => reserved
        }}
    end

    def parse_payload(%Packet{} = packet, _payload) do
        packet
    end

    def label(label) do
        << label::bytes-size(32) >>
    end

    def parse_label(payload) do
        << label::bytes-size(32) >> = payload
        String.rstrip(label, 0)
    end

    def hsbk(%HSBK{} = hsbk, duration) do
        <<
            0::little-integer-size(8),
            HSBK.hue(hsbk)::little-integer-size(16),
            HSBK.saturation(hsbk)::little-integer-size(16),
            HSBK.brightness(hsbk)::little-integer-size(16),
            HSBK.kelvin(hsbk)::little-integer-size(16),
            duration::little-integer-size(32)
        >>
    end

    def parse_hsbk(payload) do
        <<
            hue::little-integer-size(16),
            saturation::little-integer-size(16),
            brightness::little-integer-size(16),
            kelvin::little-integer-size(16),
        >> = payload
        %HSBK{:hue => hue, :saturation => saturation, :brightness => brightness, :kelvin => kelvin}
    end

    def parse_packet(payload) do
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
            :target => int_to_atom(target),
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

    def create_packet(%Packet{} = packet, payload \\ <<>>) when is_binary(payload) do
        packet = %Packet{packet |
            :frame_address => %FrameAddress{packet.frame_address |
                :target => atom_to_int(packet.frame_address.target)
            }
        }
        otap = reverse_bits(<<
            packet.frame_header.origin::size(2),
            packet.frame_header.tagged::size(1),
            packet.frame_header.addressable::size(1),
            packet.frame_header.protocol::size(12),
        >>)
        rar = reverse_bits(<<
            packet.frame_address.reserved1::size(6),
            packet.frame_address.ack_required::size(1),
            packet.frame_address.res_required::size(1),
        >>)
        p = <<
            otap::bits-size(16),
            packet.frame_header.source::little-integer-size(32),

            packet.frame_address.target::little-integer-size(64),
            packet.frame_address.reserved::little-integer-size(48),
            rar::bits-size(8),
            packet.frame_address.sequence::little-integer-size(8),

            packet.protocol_header.reserved::little-integer-size(64),
            packet.protocol_header.type::little-integer-size(16),
            packet.protocol_header.reserved1::little-integer-size(16),
        >> <> payload
        << byte_size(p)+2::little-integer-size(16) >> <> p
    end

    def reverse_bits(bits) do
        bits
        |> :erlang.binary_to_list
        |> :lists.reverse
        |> :erlang.list_to_binary
    end

    def atom_to_int(id) when id |> is_atom do
        id
        |> Atom.to_string
        |> String.to_integer
    end

    def atom_to_int(id) when id |> is_integer do
        id
    end

    def int_to_atom(id) when id |> is_integer do
        id
        |> Integer.to_string
        |> String.to_atom
    end

    def int_to_atom(id) when id |> is_atom do
        id
    end

end

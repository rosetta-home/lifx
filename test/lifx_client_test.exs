defmodule LifxTest do
    use ExUnit.Case
    use Lifx.Protocol.Types
    doctest Lifx

    alias Lifx.Protocol
    alias Lifx.Protocol.{FrameHeader, FrameAddress, ProtocolHeader}
    alias Lifx.Protocol.{Device, Packet}

    @discovery_packet %Packet{
        frame_header: %FrameHeader{
            addressable: 1,
            origin: 0,
            protocol: 1024,
            size: 36,
            source: 4102800990,
            tagged: 1
        },
        frame_address: %FrameAddress{
            ack_required: 0,
            res_required: 1,
            reserved: 0,
            reserved1: 0,
            sequence: 0,
            target: 0
        },
        protocol_header: %ProtocolHeader{
            reserved: 0,
            reserved1: 0,
            type: 2
        },
        payload: %{}
    }


    test "the truth" do
        assert 1 + 1 == 2
    end

    test "discovery packet creation" do
        data = "240000345EC68BF400000000000000000000000000000100000000000000000002000000"
        {:ok, bin} = Base.decode16(data, case: :upper)
        assert Protocol.create_packet(
            @discovery_packet.frame_header,
            @discovery_packet.frame_address,
            @discovery_packet.protocol_header
        ) == bin
    end

    test "discovery packet parsing" do
        data = "240000345EC68BF400000000000000000000000000000100000000000000000002000000"
        {:ok, bin} = Base.decode16(data, case: :upper)
        assert Protocol.parse_packet(bin) == @discovery_packet
    end
end

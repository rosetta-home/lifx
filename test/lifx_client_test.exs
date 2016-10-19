defmodule LifxTest do
    use ExUnit.Case
    use Lifx.Protocol.Types
    doctest Lifx

    alias Lifx.Protocol
    alias Lifx.Protocol.{FrameHeader, FrameAddress, ProtocolHeader}
    alias Lifx.Protocol.{Packet}
    alias Lifx.Device.State, as: Device

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
            target: :"0" #target is automatically converted to an atom for use as PID name. it is automatically converted back to int for binary transmission
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
        assert Protocol.create_packet(@discovery_packet) == bin
    end

    test "discovery packet parsing" do
        data = "240000345EC68BF400000000000000000000000000000100000000000000000002000000"
        {:ok, bin} = Base.decode16(data, case: :upper)
        assert Protocol.parse_packet(bin) == @discovery_packet
    end

    test "Client event handler" do
        Lifx.Client.start
        Lifx.Client.add_handler(Lifx.Handler)
        assert_receive(%Device{}, 10000)
    end
end

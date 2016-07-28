defmodule Lifx.Device do
    use GenServer
    use Lifx.Protocol.Types
    require Logger
    alias Lifx.Protocol.{FrameHeader, FrameAddress, ProtocolHeader}
    alias Lifx.Protocol.{Device, Packet}
    alias Lifx.Protocol.{HSBK}
    alias Lifx.Client

    defmodule State do
        defstruct id: 0,
            host: {0,0,0,0},
            port: 57600,
            label: nil,
            power: 0,
            rx: 0,
            tx: 0,
            hsbk: %HSBK{}
    end

    def start_link(%State{} = device) do
        GenServer.start_link(__MODULE__, device, name: device.id)
    end

    def set_color(device, %HSBK{} = hsbk, duration \\ 1000) when device |> is_atom do
        GenServer.cast(device, {:set_color, hsbk, duration})
    end

    def get_label(device) when device |> is_atom do
        GenServer.cast(device, :label)
    end

    def handle_packet(device, %Packet{} = packet) do
        GenServer.cast(device, {:packet, packet})
    end

    def init(%State{} = device) do
        Process.send_after(self, :label, 100)
        {:ok, device}
    end

    def handle_cast({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @statelabel}} = packet}, state) do
        s = %State{state | :label => packet.payload.label}
        GenEvent.notify(Lifx.Client.Events, s)
        {:noreply, s}
    end

    def handle_cast({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @light_state}} = packet}, state) do
        s = %State{state |
            :hsbk => packet.payload.hsbk,
            :power => packet.payload.power,
            :label => packet.payload.label,
        }
        Logger.info("Device #{inspect state.id} colors updated #{inspect s}")
        GenEvent.notify(Lifx.Client.Events, s)
        {:noreply, s}
    end

    def handle_cast({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @acknowledgement}} = packet}, state) do
        Logger.info("Device: #{inspect state.id} command acknowledged")
        {:noreply, state}
    end

    def handle_cast({:packet, %Packet{} = packet}, state) do
        Logger.info("Device: #{inspect state.id} got packet #{inspect packet}")
        {:noreply, state}
    end

    def handle_cast({:set_color, %HSBK{} = hsbk, duration}, state) do
        packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @light_setcolor}
        }
        payload = Protocol.hsbk(hsbk, duration)
        Client.send(state, packet, payload)
        {:noreply, state}
    end

    def handle_info(:label, state) do
        packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @getlabel}
        }
        Client.send(state, packet)
        {:noreply, state}
    end
end

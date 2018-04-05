defmodule Lifx.Device do
    use GenServer
    use Lifx.Protocol.Types
    require Logger
    alias Lifx.Protocol.{FrameHeader, FrameAddress, ProtocolHeader}
    alias Lifx.Protocol.{Device, Packet}
    alias Lifx.Protocol.{HSBK, Group, Location}
    alias Lifx.Protocol
    alias Lifx.Client

    defmodule State do
        defstruct id: 0,
            host: {0,0,0,0},
            port: 57600,
            label: nil,
            power: 0,
            signal: 0,
            rx: 0,
            tx: 0,
            hsbk: %HSBK{},
            group: %Group{},
            location: %Location{}
    end

    def start_link(%State{} = device) do
        GenServer.start_link(__MODULE__, device, name: device.id)
    end

    def set_color(device, %HSBK{} = hsbk, duration \\ 1000) when device |> is_atom do
        GenServer.cast(device, {:set_color, hsbk, duration})
    end

    def on(device) do
        GenServer.cast(device, {:set_power, 65535})
    end

    def off(device) do
        GenServer.cast(device, {:set_power, 0})
    end

    def get_label(device) when device |> is_atom do
        GenServer.cast(device, :label)
    end

    def handle_packet(device, %Packet{} = packet) do
        GenServer.call(device, {:packet, packet})
    end

    def init(%State{} = device) do
        Process.send_after(self, :state, 100)
        {:ok, device}
    end

    def handle_call({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @statelabel}} = packet}, _from, state) do
        s = %State{state | :label => packet.payload.label}
        notify(s)
        {:reply, s, s}
    end

    def handle_call({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @statepower}} = packet}, _from, state) do
        s = %State{state | :power => packet.payload.level}
        notify(s)
        {:reply, s, s}
    end

    def handle_call({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @stategroup}} = packet}, _from, state) do
        s = %State{state | :group => packet.payload.group}
        notify(s)
        {:reply, s, s}
    end

    def handle_call({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @statelocation}} = packet}, _from, state) do
        s = %State{state | :location => packet.payload.location}
        notify(s)
        {:reply, s, s}
    end

    def handle_call({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @light_state}} = packet}, _from, state) do
        s = %State{state |
            :hsbk => packet.payload.hsbk,
            :power => packet.payload.power,
            :label => packet.payload.label,
        }
        notify(s)
        {:reply, s, s}
    end

    def handle_call({:packet, %Packet{:protocol_header => %ProtocolHeader{:type => @statewifiinfo}} = packet}, _from, state) do
        s = %State{state |
            :signal => packet.payload.signal,
            :rx => packet.payload.rx,
            :tx => packet.payload.tx,
        }
        notify(s)
        {:reply, s, s}
    end

    def handle_call({:packet, %Packet{} = packet}, _from, state) do
        Logger.debug("Device: #{inspect state.id} got packet #{inspect packet}")
        {:reply, state, state}
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

    def handle_cast({:set_power, power}, state) do
        packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @setpower}
        }
        payload = Protocol.level(power)
        Client.send(state, packet, payload)
        {:noreply, state}
    end

    def handle_info(:state, state) do
        location_packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @getlocation}
        }
        Client.send(state, location_packet)
        label_packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @getlabel}
        }
        Client.send(state, label_packet)
        color_packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @light_get}
        }
        Client.send(state, color_packet)
        wifi_packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @getwifiinfo}
        }
        Client.send(state, wifi_packet)
        power_packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @getpower}
        }
        Client.send(state, power_packet)
        group_packet = %Packet{
            :frame_header => %FrameHeader{},
            :frame_address => %FrameAddress{:target => state.id},
            :protocol_header => %ProtocolHeader{:type => @getgroup}
        }
        Client.send(state, group_packet)
        Process.send_after(self(), :state, 5000)
        {:noreply, state}
    end

    defp notify(msg) do
        for {_, pid, _, _} <- Supervisor.which_children(Lifx.Client.Events) do
            GenServer.cast(pid, msg)
        end
        :ok
    end
end

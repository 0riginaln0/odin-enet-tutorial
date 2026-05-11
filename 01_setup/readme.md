This chapter shows a basic enet client-server setup.

- setting up server
- handling incoming requests
- connect & disconnect from the server

Build & Run:

```sh
# Shell 1
odin run server
```

```sh
# Shell 2
odin run client
```

## Field Validity by Event Type

| Field | Type | Valid For Events | Description |
|-------|------|------------------|-------------|
| `type` | `ENetEventType` | Always | The type of event that occurred (NONE, CONNECT, DISCONNECT, RECEIVE) [2](#0-1)  |
| `peer` | `ENetPeer*` | CONNECT, DISCONNECT, RECEIVE | The peer that generated the event [3](#0-2)  |
| `channelID` | `u8` | RECEIVE | The channel number on which the packet was received [4](#0-3)  |
| `data` | `u32` | CONNECT, DISCONNECT | User-supplied data describing the event (0 if none available) [5](#0-4)  |
| `packet` | `ENetPacket*` | RECEIVE | The packet that was received (must be destroyed with `enet_packet_destroy` after use) [6](#0-5)  |

### ENET_EVENT_TYPE_NONE
- **Valid fields**: `type` only
- All other fields are NULL or 0

### ENET_EVENT_TYPE_CONNECT
- **Valid fields**: `type`, `peer`, `data`
- `peer` contains the newly connected peer 
- `data` contains user-supplied data from the connection
- `channelID`, `packet` are invalid

### ENET_EVENT_TYPE_DISCONNECT
- **Valid fields**: `type`, `peer`, `data`
- `peer` contains the peer that disconnected
- `data` contains user-supplied data describing the disconnection, or 0 if none
- `channelID`, `packet` are invalid

### ENET_EVENT_TYPE_RECEIVE
- **Valid fields**: `type`, `peer`, `channelID`, `packet`
- `peer` contains the peer that sent the packet 
- `channelID` specifies the channel on which the packet was received
- `packet` contains the received packet (must be destroyed with `enet_packet_destroy`)
- `data` is invalid

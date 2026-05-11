This chapter shows the simplest multiplayer game.

- lazy protocol with encoding messages via CBOR
- unoptimized world update messages (sends whole world)
- players input and world updates thought unreliable channel
- chat messages throught reliable channel
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

```sh
# Shell 3
odin run client
```

Types of packets that can be created via `enet_packet_create()`:

| Flags | Delivery | Ordering | Use Case | Example |
|-------|----------|----------|----------|---------|
| no flags | Unreliable | Ordered (automatically drops the packet if it is older than the last received one) | Frequent updates where newer data supersedes older data (like position updates) | World updates or player input updates.  |
| `ENET_PACKET_FLAG_RELIABLE` | Reliable (guaranteed delivery with retransmission) | Ordered | Critical game state, commands, or data that must arrive | Acknowlegments, important info messages |
| `ENET_PACKET_FLAG_UNSEQUENCED` | Unreliable | Unordered | Independent events where order doesn't matter | Visual effects triggers  |
| `ENET_PACKET_FLAG_UNRELIABLE_FRAGMENT` | Unreliable | Unordered | Large packets that exceed MTU, fragmented unreliably | Time-sensitive large data transfers  |
| `ENET_PACKET_FLAG_NO_ALLOCATE` | Depends on other flags | Depends on other flags | User-supplied data buffer (ENet doesn't allocate memory) | Zero-copy packet creation  |

## Notes

The `ENET_PACKET_FLAG_SENT` flag is internal-only and set by ENet when a packet has been sent from all queues.

It's better to use one channel per one type of packets. Because If you send both unreliable and reliable packets through one channel, unreliable packets are gonna be blocked by the reliable packets.



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

# odin-enet-tutorial

This is a repository where I teach myself step by step how to use ENet library.

If you have any improvements, suggestions and so on, issues and PRs are welcome.

Knowledge was gathered from
- [ENet official documentation](http://enet.bespin.org/)
- [ENet source code](https://github.com/lsalzman/enet)
- [Usergames' ENet tutorial series](https://youtube.com/playlist?list=PLQ9u5jUZr6xP1bUzC-_BWDxIqOZuvdCgl&si=aCeVL9fIPBSik4TD)
- [Love2D framework's ENet documentation](https://tst2005.github.io/love-doc/wiki/enet.html)
- [AI-powered documentation for ENet](https://deepwiki.com/lsalzman/enet). I found it very useful, but don't trust it in all cases.

## Setup
For linux, you need to install

Debian:
```sh
sudo apt-get update
sudo apt-get install libenet-dev
```
Fedora:
```sh
sudo dnf install enet-devel
```

# Content:

- 01_setup: 
  - minimal client-server setup
  - practices of events handling
- 02_chat:
  - simple multiuser chat
  - working with packets (creating, destroying, so on)
  - connect/disconnect
- 03_realtime_multiplayer:
  - defining a simple binary protocol with CBOR library
  - unreliable channel for player input and world updates
  - reliable channel for chat messages and slot assignment
  - unoptimized world updates messages
  - fixed DT

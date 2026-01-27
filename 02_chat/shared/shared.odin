package shared

import "core:fmt"
import enet "vendor:ENet"

format_enet_address :: proc(addr: enet.Address) -> string {
    return fmt.tprintf(
        "%d.%d.%d.%d:%d",
        u8(addr.host),
        u8(addr.host >> 8),
        u8(addr.host >> 16),
        u8(addr.host >> 24),
        addr.port,
    )
}

import time

types = ["udp"]

start_all()

for machine in machines:
    machine.wait_for_unit("default.target")

server.wait_for_unit("villas-signaling-server.service")
server.wait_for_open_port(8080)

server.forward_port(guest_port=22, host_port=2000)
peer_left.forward_port(guest_port=22, host_port=2100)
peer_right.forward_port(guest_port=22, host_port=2101)

time.sleep(2)

# for typ in types:
#     peer_right.execute(f"start {typ} >&2  &")
#     time.sleep(2)
#     peer_left.execute(f"start {typ} >&2  &")

server.wait_for_shutdown()

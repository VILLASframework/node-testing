# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

import json
import asyncio
import base64
import os
from qemu import qmp
from pathlib import PosixPath
from pydantic import BaseModel
from contextlib import asynccontextmanager

from test_driver.machine import Machine
from test_driver.driver import Driver

bin = "/run/current-system/sw/bin"

test_types = ["udp" "webrtc" "sampled_values" "websocket"]

services = [
    "villas-signaling-server.service",
    "villas-websocket-relay.service",
    "fiware-orion.service",
    "mongodb.service",
]

ports = [
    8080,  # WebRTC Signaling
    8088,  # WebSocket Relay
    1883,  # MQTT Broker
    3478,  # WebRTC TURN/STUN Relay
    1026,  # FIWARE Orion Context Broker
]


class AsyncRemoteFile:
    def __init__(self, client: qmp.QMPClient, handle: int, chunk_size: int = 48 << 20):
        self.client = client
        self.handle = handle
        self.chunk_size = chunk_size

    async def seek(self, offset: int, whence: int = 0) -> tuple[bool, int]:
        if whence == 0:
            whence_str = "set"
        elif whence == 1:
            whence_str = "cur"
        elif whence == 2:
            whence_str = "end"
        else:
            raise RuntimeError("invalid whence")

        result = await self.client.execute(
            "guest-file-seek",
            {
                "handle": self.handle,
                "offset": offset,
                "whence": whence_str,
            },
        )

        eof = result.get("eof", False)
        position = result.get("position")

        return eof, position

    async def write(self, buf: bytes) -> tuple[bool, int]:
        nw = 0
        while True:
            sz = self.chunk_size
            if sz > len(buf):
                sz = len(buf)

            result = await self.client.execute(
                "guest-file-write",
                {
                    "handle": self.handle,
                    "buf-b64": base64.b64encode(buf[:sz]).decode("ascii"),
                },
            )

            buf = buf[sz:]
            nw += result.get("count", 0)
            eof = result.get("eof", False)

            if len(buf) == 0:
                break

        return eof, nw

    async def read(self, n: int = -1) -> tuple[bool, int, bytes]:
        buf = bytes()

        nr = 0
        while n < 0 or nr < n:
            sz = n
            if sz > self.chunk_size:
                sz = self.chunk_size

            result = await self.client.execute(
                "guest-file-read", {"handle": self.handle, "count": self.chunk_size}
            )

            if part := result.get("buf-b64"):
                buf += base64.b64decode(part)

            nr += result.get("count", 0)

            if eof := result.get("eof", False):
                return eof, nr, buf

        return False, nr, buf

    async def close(self):
        result = await self.client.execute("guest-file-close", {"handle": self.handle})
        self.handle = None

        return result


class TestMachine:
    def __init__(self, name: str, ssh_port: int):
        global machines

        machine = [machine for machine in machines if machine.name == name]
        if len(machine) != 1:
            raise RuntimeError(f"Unknown machine with name: {name}")

        self.base: Machine = machine[0]

        self.ssh_port = ssh_port
        self.qmp = qmp.QMPClient(self.name)
        self.qga = qmp.QMPClient(f"{self.name}-guest-agent")
        self.qga.negotiate = False
        self.qga.await_greeting = False

    async def connect_qmp(self):
        await asyncio.gather(
            self.qmp.connect(self.state_dir / "qmp2"),
            self.qga.connect(self.state_dir / "qga"),
        )

    async def disconnect_qmp(self):
        await asyncio.gather(self.qmp.disconnect(), self.qga.disconnect())

    async def start(self):
        self.base.wait_for_unit("default.target")
        self.base.forward_port(guest_port=22, host_port=self.ssh_port)

        await self.connect_qmp()

    async def execute(
        self, path: str, *args, env={}, capture_output=True, poll_interval: float = 0.1
    ):
        pid = await self.qga.execute(
            "guest-exec",
            {
                "path": path,
                "arg": args,
                "capture-output": capture_output,
            },
        )

        while True:
            result = await self.qga.execute("guest-exec-status", pid)
            if result.get("exited"):
                break

            await asyncio.sleep(poll_interval)

        for data in ["err-data", "out-data"]:
            if data not in result:
                continue

            result[data] = base64.b64decode(result[data])

        return result

    @asynccontextmanager
    async def open(self, path: PosixPath, mode: str = "r"):
        handle = await self.qga.execute(
            "guest-file-open", {"path": str(path), "mode": mode}
        )

        file = AsyncRemoteFile(self.qga, handle)

        yield file

        await file.close()

    def __getattr__(self, name):
        return getattr(self.base, name)


class Server(TestMachine):

    async def start(self):
        await super().start()

        for service in services:
            self.wait_for_unit(service)

        for port in ports:
            self.wait_for_open_port(port)


class Peer(TestMachine):
    pass


class TestSpec(BaseModel):
    name: str
    peer_left: dict
    peer_right: dict
    setup: str | None = None


class Test:

    def __init__(
        self,
        spec: TestSpec,
        server: Server,
        peer_left: Peer,
        peer_right: Peer,
    ):
        self.spec = spec

        self.server = server
        self.peer_left = peer_left
        self.peer_right = peer_right

    async def run(self):
        for peer in [self.peer_left, self.peer_right]:
            if self.spec.setup:
                log(f"Run setup script on {peer.name}")
                async with peer.open("/tmp/setup.sh", "w") as f:
                    await f.write(self.spec.setup.encode("utf-8"))

                result = await peer.execute(f"{bin}/bash", "/tmp/setup.sh")
                if result.get("exitcode") != 0:
                    err_msg = result.get("err-data").decode("utf-8")
                    raise RuntimeError(f"Failed to run setup script: {err_msg}")

        log("Rest a bit before the first test")
        await asyncio.sleep(10)

        async def start_villas(peer: Peer, cfg: dict):
            cfg_file = "/etc/villas-node.json"

            async with peer.open(cfg_file, "w") as f:
                s = json.dumps(cfg)
                await f.write(s.encode("utf-8"))

            log(f"Starting VILLASnode on {peer.name}")
            result = await peer.execute(
                f"{bin}/bash",
                "-c",
                f"{bin}/villas-node {cfg_file} 2> /dev/console > /dev/console",
            )
            log(f"Finished running VILLASnode on {peer.name}: rc={result.get('exitcode')}")

        async def left():
            # We delay start of the left peer until the right peer is ready
            await asyncio.sleep(3)
            await start_villas(self.peer_left, self.spec.peer_left)

        async def right():
            await start_villas(self.peer_right, self.spec.peer_right)

        await asyncio.wait(
            [
                asyncio.create_task(coro)
                for coro in [
                    left(),
                    right(),
                ]
            ],
            # We return when the left peer has finished the test (VILLASnode is stopped)
            return_when=asyncio.FIRST_COMPLETED,
        )


# Typing
if 0 > 1:
    driver: Driver = 1


def log(msg: str):
    print(f"========= {msg}")


async def main():
    driver.start_all()

    server = Server("server", 2000)
    peer_left = Peer("peer-left", 2100)
    peer_right = Peer("peer-right", 2101)

    await asyncio.gather(server.start(), peer_left.start(), peer_right.start())

    if True:
        test_specs_file = os.environ.get("testSpecs")
        with open(test_specs_file) as f:
            test_specs = json.load(f)

        for test_spec_dict in test_specs:
            test_spec = TestSpec(**test_spec_dict)
            test = Test(test_spec, server, peer_left, peer_right)

            log(f"Starting test: {test.spec.name}")

            await test.run()
    else:
        server.wait_for_shutdown()


try:
    asyncio.run(main())
except KeyboardInterrupt:
    log("Ctrl-C pressed")


# def tests():
#     async with server.open("/tmp/test.json", "w") as f:
#         d = {"test": "test"}
#         s = json.dumps(d)
#         await f.write(s.encode("utf-8"))

#     async with server.open("/tmp/test.json", "r") as f:
#         _, _, buf = await f.read()
#         d = json.loads(buf)
#         print(d)

#     res = await server.qmp.execute("query-commands")
#     print(res)

#     res = await server.qga.execute("guest-get-time")
#     print(res)

#     res = await server.execute(f"{bin}/bash", "-c", "uptime; sleep 1; uptime")
#     print(res)

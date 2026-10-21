#!/usr/bin/env python3
"""Resolve every name in NAMES against every server in SERVERS; print each A or AAAA address found.

Replaces `parallel host -t TYPE -W 3 :::: NAMES :::: SERVERS | rg address | awk ...`:
one process, all queries asynchronous over UDP, one attempt per query with TIMEOUT seconds,
at most PER_SERVER queries in flight and at most QPS sent per second to each server (so a silent
server costs little time and a live one is not flooded). Output: one address per line (unsorted, may
repeat) - the callers keep their `sort -u | sort -h` (and the IPv4 0.0.0.0 filter).
Stdlib only (no dnspython on this host).

usage: bulk-resolve.py A|AAAA NAMES SERVERS [--per-server N] [--qps N] [--timeout S]
"""
import argparse, asyncio, ipaddress, random, socket, struct, sys

QTYPE = {"A": 1, "AAAA": 28}


def query(name, qtype, qid):
    q = b"".join(bytes([len(p)]) + p for p in name.rstrip(".").encode("idna").split(b".") if p) + b"\0"
    return struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0) + q + struct.pack(">HH", qtype, 1)


def skip_name(m, i):
    while True:
        n = m[i]
        if n == 0:
            return i + 1
        if n & 0xC0 == 0xC0:
            return i + 2
        i += n + 1


def answers(m, qtype):
    """Addresses of the requested type anywhere in the answer section (CNAME chains included,
    as `host` prints them)."""
    qd, an = struct.unpack(">HH", m[4:8])
    i = 12
    for _ in range(qd):
        i = skip_name(m, i) + 4
    out = []
    for _ in range(an):
        i = skip_name(m, i)
        t, _c, _ttl, ln = struct.unpack(">HHIH", m[i:i + 10])
        i += 10
        if t == qtype == 1 and ln == 4:
            out.append(str(ipaddress.IPv4Address(m[i:i + 4])))
        elif t == qtype == 28 and ln == 16:
            out.append(str(ipaddress.IPv6Address(m[i:i + 16])))
        i += ln
    return out


class Server(asyncio.DatagramProtocol):
    def __init__(self, addr, qtype, per_server, qps, timeout):
        self.addr, self.qtype, self.timeout = addr, qtype, timeout
        self.slots = asyncio.Semaphore(per_server)
        self.gap, self.next_send, self.pace = 1.0 / qps, 0.0, asyncio.Lock()
        self.pending = {}  # qid -> future

    def datagram_received(self, data, _addr):
        if len(data) < 12:
            return
        qid, flags = struct.unpack(">HH", data[:4])
        fut = self.pending.pop(qid, None)
        if fut and not fut.done():
            fut.set_result(data if flags & 0x000F == 0 else None)  # rcode 0 only

    def error_received(self, _exc):
        pass

    async def resolve(self, name):
        async with self.slots:
            qid = random.randrange(65536)
            while qid in self.pending:
                qid = random.randrange(65536)
            loop = asyncio.get_running_loop()
            async with self.pace:
                now = loop.time()
                if self.next_send > now:
                    await asyncio.sleep(self.next_send - now)
                self.next_send = max(now, self.next_send) + self.gap
            fut = loop.create_future()
            self.pending[qid] = fut
            try:
                self.transport.sendto(query(name, self.qtype, qid))
                data = await asyncio.wait_for(fut, self.timeout)
            except (asyncio.TimeoutError, OSError, UnicodeError):
                return []
            finally:
                self.pending.pop(qid, None)
            try:
                return answers(data, self.qtype) if data else []
            except (struct.error, IndexError, ValueError):
                return []

    def connection_made(self, transport):
        self.transport = transport


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("type", choices=QTYPE)
    ap.add_argument("names")
    ap.add_argument("servers")
    ap.add_argument("--per-server", type=int, default=64)
    ap.add_argument("--qps", type=float, default=150)
    ap.add_argument("--timeout", type=float, default=3.0)
    a = ap.parse_args()
    names = [n.strip() for n in open(a.names) if n.strip()]
    # Keep duplicates: servers.txt lists some resolvers several times, and each query to a CDN
    # with rotating answers adds samples (the old pipeline queried every line).
    addrs = [s.strip() for s in open(a.servers) if s.strip()]
    loop = asyncio.get_running_loop()
    servers = []
    for s in addrs:
        fam = socket.AF_INET6 if ":" in s else socket.AF_INET
        _t, proto = await loop.create_datagram_endpoint(
            lambda s=s: Server(s, QTYPE[a.type], a.per_server, a.qps, a.timeout), remote_addr=(s, 53), family=fam)
        servers.append(proto)

    out = sys.stdout

    async def one(srv, n):
        for addr in await srv.resolve(n):
            out.write(addr + "\n")

    # Bound total tasks in memory: process names in chunks across all servers.
    chunk = 2000
    for k in range(0, len(names), chunk):
        await asyncio.gather(*(one(srv, n) for n in names[k:k + chunk] for srv in servers))
    out.flush()


if __name__ == "__main__":
    asyncio.run(main())

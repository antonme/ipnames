#!/usr/bin/env python3
"""Discover YouTube video cache servers (googlevideo.com) by probing guessed names.

Video hosts look like rr3---sn-n8v7kn76.googlevideo.com. The sn- part is a letter-for-letter
substitution of a cluster name ("svo07s05" = Google's own Sheremetyevo site 07, group 05;
"rostelecom-led3" = a Google Global Cache box inside Rostelecom, St Petersburg, cluster 3), and
the plain form r3.svo07s05.googlevideo.com resolves to the same address. gvt1.com twins
(rr3---sn-n8v7kn76.gvt1.com), r vs rr and --- vs . all resolve to the same IP too, so only new
clusters and new server numbers add addresses.

Candidate clusters, limited to the CITIES below:
  * clusters already seen in dns-youtube.txt / ext-dns-youtube.txt / the ion-lane web list;
  * GGC: (big Russian operators + every operator ever seen in a target city)
         x target airport codes x cluster 1..max(12, highest seen + 2);
  * Google's own sites: missing group numbers in every site seen in a target city.
Stage 1 asks for r1.<cluster>; clusters that answer get r1..r20 probed in stage 2. Everything
goes to the single fastest resolver from servers.txt. Confirmed hosts are written in both the
rN--- and rrN--- encoded forms to OUT (a list-*.txt, so names-from-cache.fish picks it up for
ext-dns-youtube.txt). OUT is only replaced when the run found something.

usage: probe-youtube.py [--out list-youtube-probed.txt] [--servers servers.txt] [--qps N]
"""
import argparse, asyncio, importlib.util, os, random, re, statistics, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.dont_write_bytecode = True  # no __pycache__ in the repo from loading bulk-resolve.py
spec = importlib.util.spec_from_file_location("bulk_resolve", os.path.join(HERE, "bulk-resolve.py"))
br = importlib.util.module_from_spec(spec)
spec.loader.exec_module(br)

CIPHER = "7elsz6dkry5cjqx4bipw3ahov29gnu08fmt1"
PLAIN = "0123456789abcdefghijklmnopqrstuvwxyz"
DECODE = str.maketrans(CIPHER, PLAIN)
ENCODE = str.maketrans(PLAIN, CIPHER)

# Airport codes Google uses for each wanted city (several per city where it has them).
CITIES = {
    "Moscow": "svo dme vko mow", "St Petersburg": "led", "Tallinn": "tll", "Riga": "rix",
    "Helsinki": "hel", "Minsk": "msq", "Vladikavkaz": "ogz", "Warsaw": "waw wmi",
    "Frankfurt": "fra", "Stockholm": "arn bma sto", "Vilnius": "vno",
    "London": "lhr lgw lcy stn ltn lon", "Amsterdam": "ams",
    "New York": "lga jfk ewr hpn nyc", "Philadelphia": "phl", "Chicago": "ord mdw chi",
    "Atlanta": "atl", "Dallas": "dfw dal", "San Francisco": "sfo sjc oak nuq",
}
IATA = {c for codes in CITIES.values() for c in codes.split()}
# Operator names from https://habr.com/ru/articles/828762/ (GGC in Russia).
RU_OPERATORS = {"rostelecom", "vimpelcom", "comstar", "megafon", "ertelecom", "transtelecom", "netbynet"}
WEB_LISTS = ["https://raw.githubusercontent.com/ion-lane/googlevideo_lists/HEAD/googlevideo.txt"]

GGC = re.compile(r"([a-z0-9]+)-([a-z]{3})(\d{1,2})")
SITE = re.compile(r"([a-z]{3})(\d\d)s(\d\d)")
HOST = re.compile(r"(?:^|[^a-z0-9-])r{1,2}\d+(?:---|\.)sn-([a-z0-9-]+)\.(?:googlevideo|gvt1)\.com")


def seen_clusters(texts):
    out = set()
    for t in texts:
        for code in HOST.findall(t):
            name = code.translate(DECODE)
            if GGC.fullmatch(name) or SITE.fullmatch(name):
                out.add(name)
    return out


def city_of(cluster):
    if m := GGC.fullmatch(cluster):
        return m[2]
    if m := SITE.fullmatch(cluster):
        return m[1]


def candidates(seen):
    ggc_max, operators, sites = {}, set(RU_OPERATORS), {}
    for c in seen:
        if m := GGC.fullmatch(c):
            op, city, n = m[1], m[2], int(m[3])
            ggc_max[(op, city)] = max(ggc_max.get((op, city), 0), n)
            if city in IATA:
                operators.add(op)
        elif (m := SITE.fullmatch(c)) and m[1] in IATA:
            sites.setdefault(m[1] + m[2], set()).add(int(m[3]))
    cand = {c for c in seen if city_of(c) in IATA}
    for op in operators:
        for city in IATA:
            for n in range(1, max(12, ggc_max.get((op, city), 0) + 2) + 1):
                cand.add(f"{op}-{city}{n}")
    for site, groups in sites.items():
        for g in range(1, min(99, max(groups) + 10) + 1):
            cand.add(f"{site}s{g:02d}")
    return cand, len(operators), len(sites)


def fetch(url):
    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            return r.read(5_000_000).decode("utf-8", "replace")
    except Exception as e:
        print(f"  {url}: {e}", file=sys.stderr)
        return ""


async def make_server(addr, qps):
    loop = asyncio.get_running_loop()
    fam = br.socket.AF_INET6 if ":" in addr else br.socket.AF_INET
    _t, proto = await loop.create_datagram_endpoint(
        lambda: br.Server(addr, 1, 64, qps, 2.0), remote_addr=(addr, 53), family=fam)
    return proto


async def fastest(addrs, probe_names, qps):
    """Median time for 5 known-good names (different per server, so caches don't help)."""
    loop = asyncio.get_running_loop()
    results = []

    async def bench(addr, names):
        srv = await make_server(addr, qps)
        times = []
        for n in names:
            t = loop.time()
            if await srv.resolve(n):
                times.append(loop.time() - t)
        srv.transport.close()
        if len(times) >= 4:
            results.append((statistics.median(times), addr))

    pool = list(probe_names)
    random.shuffle(pool)
    await asyncio.gather(*(bench(a, pool[i * 5:i * 5 + 5]) for i, a in enumerate(addrs)))
    return min(results)[1] if results else None


async def probe(srv, names):
    hits = set()

    async def one(n):
        if await srv.resolve(n):
            hits.add(n)

    for k in range(0, len(names), 2000):
        await asyncio.gather(*(one(n) for n in names[k:k + 2000]))
    return hits


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="list-youtube-probed.txt")
    ap.add_argument("--servers", default="servers.txt")
    ap.add_argument("--qps", type=float, default=300)
    a = ap.parse_args()
    t0 = time.time()

    texts = [open(f).read() for f in ("dns-youtube.txt", "ext-dns-youtube.txt", a.out) if os.path.exists(f)]
    texts += [fetch(u) for u in WEB_LISTS]
    seen = seen_clusters(texts)
    cand, n_ops, n_sites = candidates(seen)
    print(f"  {len(seen)} known clusters, {n_ops} operators, {n_sites} Google sites"
          f" -> {len(cand)} candidate clusters in {len(IATA)} airport codes")

    addrs = list(dict.fromkeys(s.strip() for s in open(a.servers) if s.strip()))
    known = sorted(seen)
    random.shuffle(known)
    best = await fastest(addrs, [f"r1.{c}.googlevideo.com" for c in known[:5 * len(addrs)]], a.qps)
    if not best:
        sys.exit("  no resolver answered; keeping previous " + a.out)
    print(f"  resolver: {best}")
    srv = await make_server(best, a.qps)

    live = await probe(srv, [f"r1.{c}.googlevideo.com" for c in sorted(cand)])
    clusters = sorted(n.split(".")[1] for n in live)
    print(f"  stage 1: {len(clusters)} live clusters ({len(set(clusters) - seen)} new)")

    hosts = await probe(srv, [f"r{i}.{c}.googlevideo.com" for c in clusters for i in range(1, 21)])
    out = set()
    for h in hosts:
        r, c = h.split(".")[:2]
        enc = c.translate(ENCODE)
        out.add(f"{r}---sn-{enc}.googlevideo.com")
        out.add(f"r{r}---sn-{enc}.googlevideo.com")
    print(f"  stage 2: {len(hosts)} live servers -> {len(out)} names, {time.time() - t0:.0f}s")

    if out:
        with open(a.out + ".partial", "w") as f:
            f.writelines(n + "\n" for n in sorted(out))
        os.replace(a.out + ".partial", a.out)
    else:
        print("  nothing found; keeping previous " + a.out)


if __name__ == "__main__":
    asyncio.run(main())

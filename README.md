# Popular Sites/Platforms FQDNs and Resolved IPs
This repo contains daily updated list of FQDNs and resolved IPs of some popular sites/platforms. Made for my personal needs in routing of some VPNs in my router to fight censure and balkanization of the Internet a little.

Sites/platforms included: Adobe, Apple, Backblaze, Bing, Facebook, GitHub, Google, NordVPN, OpenAI, Ozon, Pornhub, TikTok, Twitter, YouTube

## Repository Structure

### Data Files

| File Pattern | Description |
|--------------|-------------|
| `dns-*.txt` | FQDNs filtered from smaller, current DNS logs |
| `ext-dns-*.txt` | FQDNs filtered from larger external sources |
| `resolve-*.txt` | Resolved IPv4 addresses from `dns-*.txt` |
| `ipv6-resolve-*.txt` | Resolved IPv6 addresses from `dns-*.txt` |

### Configuration Files

- `servers.txt`, `servers-ext.txt`: DNS server lists for resolving names
- `full-update.fish`: Script for full cycle update
- `names-from-cache.fish`: Filters FQDNs from available logs
- `presolve*.fish`: Scripts to resolve IPs from FQDNs

## Methodology

1. Service FDQNs are collected from available DNS logs and popular site/FDQN lists
2. FQDN lists are filtered and updated daily
3. FQDNs are resolved daily to IPv4 and IPv6 addresses using multiple DNS servers across regions
4. DNS servers include Google, Cloudflare, AdGuard, Comodo, and my personal custom servers (full list in `servers.txt` and 'servers-ext.txt')
5. Resolution occurs in multiple regions (NY, Stockholm, Riga, St. Petersburg, Moscow, Almaty) to include CDN addresses

## External Sources

- [Cloudflare Radar](https://radar.cloudflare.com/)
- [Cisco Umbrella](https://umbrella-static.s3-us-west-1.amazonaws.com/index.html)
- [DomCop's Top 10 Million Domains](https://www.domcop.com/top-10-million-websites)
- [The Majestic Million](https://majestic.com/reports/majestic-million)
- [OpenINTEL](https://www.openintel.nl/)
- [WhoisXMLAPI](https://subdomains.whoisxmlapi.com/api)

## Sister repos
Here's list of another data I use for my router configs:
  * [ipranges](https://github.com/antonme/ipranges): list IP ranges of: Google, Bing, Amazon, Microsoft, Azure, Oracle, DigitalOcean, GitHub, Facebook, Twitter, Linode, Yandex, Vkontakte with regular auto-updates
  * [geoip](https://github.com/antonme/geoip): lists of CIDR's by regions for routing VPNs in my router

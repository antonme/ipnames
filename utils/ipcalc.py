import ipaddress
import sys

def range_to_cidr(start, end):
    start = ipaddress.IPv4Address(start)
    end = ipaddress.IPv4Address(end)
    network = ipaddress.summarize_address_range(start, end)
    
    return [str(net) for net in network]

if __name__ == "__main__":
    for line in sys.stdin:
        start, end = line.strip().split()
        result = range_to_cidr(start, end)
        for net in result:
            print(net)

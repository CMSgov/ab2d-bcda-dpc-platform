# USAGE: cat [file].csv | python ips_to_cidr.py

import fileinput
import ipaddress
import sys

ips = {
  'v4': [],
  'v4_network': [],
  'v6': [],
  'v6_network': []
}

for line in fileinput.input():
  if not fileinput.isfirstline():
    line_cleaned = line.strip('"\n"\r')
    if '/' in line_cleaned:
      try:
        ip = ipaddress.ip_network(line_cleaned, strict=False)
        if isinstance(ip, ipaddress.IPv4Network):
          ips['v4_network'].append(ip)
        elif isinstance(ip, ipaddress.IPv6Network):
          ips['v6_network'].append(ip)
      except ValueError as e:
        print(f"An exception occurred when parsing the following IP Network: {line_cleaned}\n", e, file=sys.stderr)
    else:
      try:
        ip = ipaddress.ip_address(line_cleaned)
        if isinstance(ip, ipaddress.IPv4Address):
          ips['v4'].append(ip)
        elif isinstance(ip, ipaddress.IPv6Address):
          ips['v6'].append(ip)
      except ValueError as e:
        print(f"An exception occurred when parsing the following IP Address: {line_cleaned}\n", e, file=sys.stderr)

print(*list(ipaddress.collapse_addresses(ips['v4'])) + ips['v4_network'], sep='\n')
print(*list(ipaddress.collapse_addresses(ips['v6'])) + ips['v6_network'], sep='\n')

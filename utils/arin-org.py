# Import requests for making API calls
import requests

# Import netaddr for manipulating CIDRs
import netaddr

# Import sys for accessing command line arguments
import sys

# Check if an org_handle was provided as a command line argument
if len(sys.argv) > 1:
    # Get the org_handle from the first argument
    org_handle = sys.argv[1]
else:
    # Print an error message and exit if no org_handle was given
    print("Please provide an organization handle as a command line argument.")
    sys.exit(1)

# Define the base URL for ARIN's Whois-RWS API
base_url = "https://whois.arin.net/rest/"

# Define the headers for requesting XML data
headers = {"Accept": "application/xml"}

# Make a GET request to get the networks for the organization
response = requests.get(base_url + "org/" + org_handle + "/nets", headers=headers)

# Check if the response status code is 200 (OK)
if response.status_code == 200:
    # Parse the XML data from the response
    xml_data = response.text

    # Initialize an empty list for storing CIDRs
    cidrs = []

    # Loop through each network element in the XML data
    for net in xml_data.split("<netRef ")[1:]:
        # Extract the startAddress and endAddress attributes
        start_address = net.split('startAddress="')[1].split('"')[0]
        end_address = net.split('endAddress="')[1].split('"')[0]

        # Convert them to IP addresses using netaddr.IPAddress()
        start_ip = netaddr.IPAddress(start_address)
        end_ip = netaddr.IPAddress(end_address)

        # Create an IP range using netaddr.IPRange()
        ip_range = netaddr.IPRange(start_ip, end_ip)

        # Convert it to a list of CIDRs using cidrs() method
        ip_cidrs = ip_range.cidrs()

        # Append each CIDR to the cidrs list
        for cidr in ip_cidrs:
            cidrs.append(cidr)

    # Print out the number and list of CIDRs
    print("\n".join(str(cidr) for cidr in cidrs))

else:
    # Print out an error message if something went wrong
    print(f"Something went wrong. Status code: {response.status_code}")

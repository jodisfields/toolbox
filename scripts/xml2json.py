import xml.etree.ElementTree as ET
import json
import argparse

def parse_port(port_element):
    """
    Parse individual port elements.
    """
    port_data = {
        "protocol": port_element.get("protocol"),
        "portid": port_element.get("portid"),
        "state": port_element.find("state").get("state"),
        "service": port_element.find("service").get("name") if port_element.find("service") is not None else None
    }
    return port_data

def parse_os(os_element):
    """
    Parse OS detection elements, only including those with 100% accuracy.
    """
    os_matches = []
    for osmatch in os_element.findall("osmatch"):
        if osmatch.get("accuracy") == "100":
            os_matches.append({
                "name": osmatch.get("name"),
                "accuracy": osmatch.get("accuracy"),
                "line": osmatch.get("line"),
                "osclasses": [{"osgen": osclass.get("osgen")} for osclass in osmatch.findall("osclass")]
            })
    return os_matches

def parse_host(host_element):
    """
    Parse individual host elements.
    """
    host_data = {
        "status": host_element.find("status").get("state"),
        "address": host_element.find("address").get("addr"),
        "ports": [parse_port(port) for port in host_element.findall(".//ports/port")],
        "os": parse_os(host_element.find("os")) if host_element.find("os") is not None else None
    }
    return host_data

def convert_xml_to_json(input_file, output_file):
    """
    Convert Nmap XML file to JSON file.
    """
    try:
        tree = ET.parse(input_file)
        root = tree.getroot()
        data = {"hosts": [parse_host(host) for host in root.findall("host")]}

        with open(output_file, 'w') as json_file:
            json.dump(data, json_file, indent=4)

        print(f"Nmap XML file '{input_file}' successfully converted to JSON file '{output_file}'")
    except Exception as e:
        print(f"Error: {e}")

def main():
    parser = argparse.ArgumentParser(description="Convert Nmap XML to JSON")
    parser.add_argument("input_xml", help="Input Nmap XML file path")
    parser.add_argument("output_json", help="Output JSON file path")
    args = parser.parse_args()

    convert_xml_to_json(args.input_xml, args.output_json)

if __name__ == "__main__":
    main()


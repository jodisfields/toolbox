package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"

	"github.com/scrapli/scrapligo/driver/options"
	"github.com/scrapli/scrapligo/platform"
)

var (
	port          = flag.Int("port", 22, "SSH port number")
	keyPath       = flag.String("keypath", os.Getenv("HOME")+"/.ssh/id_rsa", "Path to the SSH private key")
	concurrency   = flag.Int("concurrency", 10, "Number of concurrent command executions")
	outputPath    = flag.String("output", "", "Path to the output file")
	platformName  = flag.String("platform", "linux", "Platform name (e.g., linux, juniper, cisco_iosxe, arista_eos)")
	transport     = flag.String("transport", "system", "Transport type (system, standard, or paramiko)")
	enableCommand = flag.String("enable", "", "Enable command for privileged mode (e.g., 'enable' for Cisco devices)")
)

func main() {
	log.SetFlags(0)
	flag.Parse()

	var cmdIndex int
	var userHost string
	rawCmd := ""
	for i, arg := range os.Args {
		if arg == "-cmd" {
			cmdIndex = i + 1
			break
		}
		if i == 1 {
			userHost = arg
		}
	}

	if cmdIndex == 0 || cmdIndex >= len(os.Args) {
		log.Fatalln("Usage: Provide the SSH host and command(s) to execute remotely.\n" +
			"Example: ssh-run user@hostname -cmd 'command1, command2 --foo bar'")
	}

	rawCmd = strings.Join(os.Args[cmdIndex:], " ")

	if userHost == "" {
		log.Fatalln("Host must be specified.")
	}
	if rawCmd == "" {
		log.Fatalln("Command must be specified with -cmd.")
	}

	commands := parseCommands(rawCmd)
	if err := run(userHost, commands); err != nil {
		log.Fatalf("Error: %v\n", err)
	}
}

func run(userHost string, commands []string) error {
	user, host, err := parseUserHost(userHost)
	if err != nil {
		return fmt.Errorf("invalid target format: %v", err)
	}

	p, err := platform.NewPlatform(
		*platformName,
		host,
		options.WithAuthNoStrictKey(),
		options.WithAuthUsername(user),
		options.WithAuthPrivateKeyFile(*keyPath),
		options.WithPort(*port),
		options.WithTransportType(*transport),
	)
	if err != nil {
		return fmt.Errorf("failed to create platform: %v", err)
	}

	d, err := p.GetNetworkDriver()
	if err != nil {
		return fmt.Errorf("failed to create network driver: %v", err)
	}

	if *enableCommand != "" {
		d.OnOpen(d.AcquirePriv(*enableCommand))
	}

	if err = d.Open(); err != nil {
		return fmt.Errorf("failed to open connection: %v", err)
	}
	defer d.Close()

	var outputFile *os.File
	if *outputPath != "" {
		outputFile, err = os.Create(*outputPath)
		if err != nil {
			return fmt.Errorf("failed to create output file: %v", err)
		}
		defer outputFile.Close()
	}

	executeCommands(commands, d, outputFile)

	return nil
}

func parseUserHost(target string) (user, host string, err error) {
	parts := strings.Split(target, "@")
	if len(parts) != 2 {
		return "", "", fmt.Errorf("expected format user@host")
	}
	return parts[0], parts[1], nil
}

func parseCommands(cmd string) []string {
	commands := make([]string, 0)
	current := ""
	inQuotes := false
	for _, r := range cmd {
		if r == ',' && !inQuotes {
			commands = append(commands, strings.TrimSpace(current))
			current = ""
		} else if r == '"' {
			inQuotes = !inQuotes
		} else {
			current += string(r)
		}
	}
	if strings.TrimSpace(current) != "" {
		commands = append(commands, strings.TrimSpace(current))
	}
	return commands
}

func executeCommands(commands []string, d *platform.Driver, outputFile *os.File) {
	var wg sync.WaitGroup
	sem := make(chan struct{}, *concurrency)

	for _, cmd := range commands {
		sem <- struct{}{}
		wg.Add(1)
		go func(command string) {
			defer func() {
				<-sem
				wg.Done()
			}()

			response, err := d.SendCommand(command)
			if err != nil {
				log.Printf("Error executing %s: %v\n", command, err)
			} else {
				output := fmt.Sprintf("Output of %s: %s\n", command, response.Result)
				log.Print(output)
				if outputFile != nil {
					outputFile.WriteString(output)
				}
			}
		}(cmd)
	}
	wg.Wait()
}

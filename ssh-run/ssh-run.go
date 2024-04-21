package main

import (
	"bytes"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/knownhosts"
)

var (
	port    = flag.Int("port", 22, "SSH port number")
	keyPath = flag.String("keypath", os.Getenv("HOME")+"/.ssh/id_rsa", "Path to the SSH private key")
)

func main() {
	log.SetFlags(0) // Set logging to have no prefixed date/time
	flag.Parse()    // Parse known flags

	// Determine the position of the '-cmd' argument
	var cmdIndex int
	var userHost string
	rawCmd := ""
	for i, arg := range os.Args {
		if arg == "-cmd" {
			cmdIndex = i + 1
			break
		}
		if i == 1 { // Assuming the first argument is user@host
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
	if err := validatePort(*port); err != nil {
		return fmt.Errorf("port validation error: %v", err)
	}

	user, host, err := parseUserHost(userHost)
	if err != nil {
		return fmt.Errorf("invalid target format: %v", err)
	}

	signer, err := getSigner(*keyPath)
	if err != nil {
		return fmt.Errorf("failed to get SSH signer: %v", err)
	}

	hostKeyCallback, err := createHostKeyCallback()
	if err != nil {
		return fmt.Errorf("failed to set up host key verification: %v", err)
	}

	config := &ssh.ClientConfig{
		User:            user,
		Auth:            []ssh.AuthMethod{ssh.PublicKeys(signer)},
		HostKeyCallback: hostKeyCallback,
		Timeout:         10 * time.Second,
	}

	address := fmt.Sprintf("%s:%d", host, *port)
	connection, err := ssh.Dial("tcp", address, config)
	if err != nil {
		return fmt.Errorf("failed to dial: %v", err)
	}
	defer connection.Close()

	executeCommands(commands, connection)

	return nil
}

func validatePort(port int) error {
	if port < 1 || port > 65535 {
		return fmt.Errorf("port number %d is out of the valid range (1-65535)", port)
	}
	return nil
}

func parseUserHost(target string) (user, host string, err error) {
	parts := strings.Split(target, "@")
	if len(parts) != 2 {
		return "", "", fmt.Errorf("expected format user@host")
	}
	return parts[0], parts[1], nil
}

func getSigner(keyPath string) (ssh.Signer, error) {
	key, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("unable to read private key: %v", err)
	}

	signer, err := ssh.ParsePrivateKey(key)
	if err != nil {
		return nil, fmt.Errorf("unable to parse private key: %v", err)
	}
	return signer, nil
}

func createHostKeyCallback() (ssh.HostKeyCallback, error) {
	knownHostsPath := os.Getenv("HOME") + "/.ssh/known_hosts"
	callback, err := knownhosts.New(knownHostsPath)
	if err != nil {
		return nil, fmt.Errorf("error setting up known hosts: %v", err)
	}
	return callback, nil
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

func executeCommands(commands []string, connection *ssh.Client) {
	var wg sync.WaitGroup
	for _, cmd := range commands {
		wg.Add(1)
		go func(command string) {
			defer wg.Done()
			output, err := runCommand(command, connection)
			if err != nil {
				log.Printf("Error executing %s: %v\n", command, err)
			} else {
				log.Printf("Output of %s: %s\n", command, output)
			}
		}(cmd)
	}
	wg.Wait()
}

func runCommand(cmd string, connection *ssh.Client) (string, error) {
	session, err := connection.NewSession()
	if err != nil {
		return "", fmt.Errorf("failed to create session: %v", err)
	}
	defer session.Close()

	var outputBuffer bytes.Buffer
	session.Stdout = &outputBuffer
	if err := session.Run(cmd); err != nil {
		return "", fmt.Errorf("failed to run command: %v", err)
	}

	return outputBuffer.String(), nil
}

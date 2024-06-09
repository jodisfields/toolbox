package main

import (
	"bufio"
	"flag"
	"fmt"
	"log"
	"os"
	"strings"
	"syscall"
	"time"

	"golang.org/x/crypto/ssh"
	"golang.org/x/crypto/ssh/knownhosts"
	"golang.org/x/term"
)

var (
	port = flag.Int("port", 22, "SSH port number")
)

func main() {
	log.SetFlags(0)
	flag.Parse()

	if flag.NArg() != 2 {
		log.Fatalln("Usage: ssh-run user@hostname 'command1, command2, command3'")
	}

	userHost := flag.Arg(0)
	rawCommands := flag.Arg(1)

	if userHost == "" {
		log.Fatalln("Host must be specified.")
	}
	if rawCommands == "" {
		log.Fatalln("Commands must be specified.")
	}

	password := promptPassword()

	commands := parseCommands(rawCommands)
	if err := run(userHost, password, commands); err != nil {
		log.Fatalf("Error: %v\n", err)
	}
}

func run(userHost string, password string, commands []string) error {
	if err := validatePort(*port); err != nil {
		return fmt.Errorf("port validation error: %v", err)
	}

	user, host, err := parseUserHost(userHost)
	if err != nil {
		return fmt.Errorf("invalid target format: %v", err)
	}

	hostKeyCallback, err := createHostKeyCallback()
	if err != nil {
		return fmt.Errorf("failed to create host key callback: %v", err)
	}

	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.Password(password),
		},
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
	parts := strings.SplitN(target, "@", 2)
	if len(parts) != 2 {
		return "", "", fmt.Errorf("expected format user@host")
	}
	return parts[0], parts[1], nil
}

func createHostKeyCallback() (ssh.HostKeyCallback, error) {
	knownHostsPath := os.Getenv("HOME") + "/.ssh/known_hosts"
	callback, err := knownhosts.New(knownHostsPath)
	if err != nil {
		return nil, fmt.Errorf("error setting up known hosts: %v", err)
	}
	return callback, nil
}

func parseCommands(rawCommands string) []string {
	return strings.Split(rawCommands, ",")
}

func executeCommands(commands []string, connection *ssh.Client) {
	session, err := connection.NewSession()
	if err != nil {
		log.Fatalf("Failed to create session: %v\n", err)
	}
	defer session.Close()

	modes := ssh.TerminalModes{
		ssh.ECHO:          0,     // Disable echoing
		ssh.TTY_OP_ISPEED: 14400, // Input speed = 14.4kbaud
		ssh.TTY_OP_OSPEED: 14400, // Output speed = 14.4kbaud
	}

	if err := session.RequestPty("xterm", 80, 40, modes); err != nil {
		log.Fatalf("Request for pseudo terminal failed: %v\n", err)
	}

	stdin, err := session.StdinPipe()
	if err != nil {
		log.Fatalf("Failed to create stdin pipe: %v\n", err)
	}

	stdout, err := session.StdoutPipe()
	if err != nil {
		log.Fatalf("Failed to create stdout pipe: %v\n", err)
	}

	if err := session.Shell(); err != nil {
		log.Fatalf("Failed to start shell: %v\n", err)
	}

	for _, cmd := range commands {
		cmd = strings.TrimSpace(cmd)
		log.Printf("Executing command: %s\n", cmd)
		stdin.Write([]byte(cmd + "\n"))
	}

	stdin.Write([]byte("exit\n"))
	stdin.Close()

	scanner := bufio.NewScanner(stdout)
	for scanner.Scan() {
		fmt.Println(scanner.Text())
	}

	if err := scanner.Err(); err != nil {
		log.Printf("Error reading output: %v\n", err)
	}
}

func promptPassword() string {
	fmt.Print("Enter password: ")
	bytePassword, err := term.ReadPassword(int(syscall.Stdin))
	if err != nil {
		log.Fatalf("Failed to read password: %v\n", err)
	}
	fmt.Println()
	return string(bytePassword)
}

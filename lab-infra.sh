#!/bin/bash
set -e
file=$0
#Generate SSH Keys
generate_ssh() {
    if [ ! -f "/root/.ssh/id_rsa.pub" ]; then
        echo "Generating SSH key..."
        ssh-keygen -q -N '' -f ~/.ssh/id_rsa <<<y >/dev/null 2>&1
    else
        echo "SSH key already exists."
    fi
}
# Install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh >/dev/null
        sudo sh ./get-docker.sh
    else
        echo "Docker is already installed."
    fi
}
# Install kind
install_kind() {
    if ! command -v kind &> /dev/null; then
        echo "Installing kind..."
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.19.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/bin/
    else
        echo "kind is already installed."
    fi
}
# Install kubectl
install_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "Installing kubectl..."
        KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
        curl -LO "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
        curl -LO "https://dl.k8s.io/$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
        echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        echo "source <(kubectl completion bash)" >> ~/.bashrc
        echo 'alias k=kubectl' >> ~/.bashrc
        echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
        source ~/.bashrc
        echo "kubectl is installed. Run 'source ~/.bashrc' to activate the 'k' alias."
    else
        echo "kubectl is already installed."
    fi
}
# Install Go
install_go() {
    # Check if Go is already installed
    if find / -name go -type d | grep -q go;
    then
        echo "Go is already installed."
        exit 0
    else
    go_version="1.20.5"
    go_install_dir="/usr/local"
    # Download Go archive
    echo "Downloading Go..."
    wget -q https://golang.org/dl/go${go_version}.linux-amd64.tar.gz -P /tmp

    # Extract Go archive
    echo "Extracting Go..."
    sudo tar -C ${go_install_dir} -xzf /tmp/go${go_version}.linux-amd64.tar.gz

    # Set Go environment variables in .bashrc
    echo "Setting Go environment variables..."
    echo "export PATH=\$PATH:${go_install_dir}/go/bin" >> ~/.bashrc
    echo "export GOPATH=\$HOME/go" >> ~/.bashrc
    echo "export GOROOT=${go_install_dir}/go" >> ~/.bashrc
    echo "export GOBIN=\$GOPATH/bin" >> ~/.bashrc

    # Source .bashrc to load the updated environment variables
    source ~/.bashrc

    echo "Go ${go_version} has been installed successfully. Please run source ~/.bashrc to load the environment variables."
    fi
}

# Remove Docker
remove_docker() {
    if command -v docker &> /dev/null; then
        echo "Removing Docker..."
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io
        sudo rm -rf /var/lib/docker
        sudo rm -rf /etc/docker
        sudo apt autoremove -y
    else
        echo "Docker is not installed."
    fi
}

# Remove kind
remove_kind() {
    echo "Removing kind..."
    # Use find command to locate and delete the kind file
    find / -name kind -type f -exec sudo rm -f {} \; 2>/dev/null
    echo "kind has been successfully deleted."
}

# Remove kubectl
remove_kubectl() {
    if command -v kubectl &> /dev/null; then
        echo "Removing kubectl..."
        sudo rm -f /usr/local/bin/kubectl
        sed -i '/source <(kubectl completion bash)/d' ~/.bashrc
        sed -i '/alias k=kubectl/d' ~/.bashrc
        sed -i '/complete -o default -F __start_kubectl k/d' ~/.bashrc
        sudo apt autoremove -y
    else
        echo "kubectl is not installed."
    fi
}

# Remove Go
remove_go() {
    local go_install_dir=$1
    if ! find / -name go -type d | grep -q go;
    then
        echo "Go is not installed."
        exit 0
    else
    # Remove Go installation directory
    echo "Removing Go installation..."
    sudo rm -rf ${go_install_dir}/go
    # Remove Go environment variables from .bashrc
    sed -i '/^export PATH=\$PATH:'"${go_install_dir//\//\\/}"'\/go\/bin$/d' ~/.bashrc
    sed -i '/^export GOPATH=\$HOME\/go$/d' ~/.bashrc
    sed -i '/^export GOROOT='"${go_install_dir//\//\\/}"'\/go$/d' ~/.bashrc
    sed -i '/^export GOBIN=\$GOPATH\/bin$/d' ~/.bashrc
    find / -name go -type d -exec rm -rf {} \; 2>/dev/null
    echo "Go has been removed successfully."
    exit 0
    fi
}

# Install all components
install_all() {
    install_kind
    install_docker
    install_kubectl
    install_go
    generate_ssh
}

# Remove all components
remove_all() {
    remove_docker
    remove_kind
    remove_kubectl
    remove_go
}

# Display help
display_help() {
    echo "Usage: $file [command]"
    echo "Commands:"
    echo "  install      Install components (docker, kind, kubectl)"
    echo "  remove       Remove components (docker, kind, kubectl)"
    echo "  help         Display this help message"
}

display_help_install() {
    echo "Usage: $file install [options]"
    echo "Options:"
    echo "  kind      Install kind"
    echo "  kubectl   Install kubectl"
    echo "  docker    Install docker"
    echo "  ssh       Generate SSH Keys"
    echo "  go        Install Go"
    echo "  all       Install all components (Docker, kind, kubectl)"
}

display_help_remove() {
    echo "Usage: $file remove [options]"
    echo "Options:"
    echo "  docker    Remove Docker"
    echo "  kind      Remove kind"
    echo "  kubectl   Remove kubectl"
    echo "  go        Remove Go"
    echo "  all       Remove all components"
    echo "  help      Display this help message"
}

# Main script
if [ $# -eq 0 ]; then
    echo "Please specify a command. Use 'help' for more information."
    display_help
    exit 1
fi

command="$1"
case $command in
    install)
        shift
        if [ $# -eq 0 ]; then
            echo "Please specify the component(s) to install. Use 'help' for more information."
            display_help_install
            exit 1
        fi
        for component in "$@"; do
            case $component in
                kind)
                    install_kind
                    ;;
                docker)
                    install_docker
                    ;;
                ssh-key)
                    generate_ssh
                    ;;
                kubectl)
                    install_kubectl
                    ;;
                ssh)
                    generate_ssh
                    ;;
                go)
                    install_go $go_version $go_install_dir
                    ;;
                all)
                    install_all
                    ;;
                *)
                    echo "Invalid component: $component. Use 'help' for more information."
                    display_help_install
                    exit 1
                    ;;
            esac
        done
        ;;
    remove)
        shift
        if [ $# -eq 0 ]; then
            echo "Please specify the component(s) to remove. Use 'help' for more information."
            display_help_remove
            exit 1
        fi
        for component in "$@"; do
            case $component in
                kind)
                    remove_kind
                    ;;
                docker)
                    remove_docker
                    ;;
                kubectl)
                    remove_kubectl
                    ;;
                go)
                    remove_go $go_install_dir
                    ;;
                all)
                    remove_all
                    exit 0
                    ;;
                *)
                    echo "Invalid component: $component. Use 'help' for more information."
                    display_help_remove
                    exit 1
                    ;;
            esac
        done
        ;;
    help)
        display_help
        exit 0
        ;;
    *)
        echo "Invalid command: $command. Use 'help' for more information."
        display_help
        exit 1
        ;;
esac

exit 0

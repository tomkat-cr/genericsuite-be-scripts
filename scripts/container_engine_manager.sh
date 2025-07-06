#!/bin/bash
# container_engine_manager.sh
# 2025-06-23 | CR

# Usage:
# sh container_engine_manager.sh <action> <engine> <open_containers_engine_app>
#   action: start, stop, restart, status
#   engine: docker, [podman]
#   open_containers_engine_app: [1]/0

set_default_values() {
    # Set default values
    if [ "${CONTAINERS_ENGINE}" = "" ]; then
        # Default containers engine:
        CONTAINERS_ENGINE="docker"
        # CONTAINERS_ENGINE="podman"
    fi
    if [ "${OPEN_CONTAINERS_ENGINE_APP}" = "" ]; then
        # Open containers engine app automatically by default
        OPEN_CONTAINERS_ENGINE_APP="1"
    fi
    # Set commands to call the containers engine
    if [ "${CONTAINERS_ENGINE}" = "podman" ]; then
        export DOCKER_CMD="podman"
        export DOCKER_COMPOSE_CMD="podman compose"
    else
        export DOCKER_CMD="docker"
        export DOCKER_COMPOSE_CMD="docker compose"
    fi
}

start_docker_engine() {
    if ! docker ps > /dev/null 2>&1;
    then
        export DOCKER_WAS_NOT_RUNNING="1"
        if [ "${OPEN_CONTAINERS_ENGINE_APP}" = "1" ]; then
            echo ""
            echo "Opening Docker Desktop..."
            if ! sudo open "/Applications/Docker.app"
            then
                echo "" 
                echo "ERROR: Could not run Docker Desktop automatically"
                exit 1
            else
                sleep 20
            fi
        fi
        if ! docker ps > /dev/null 2>&1;
        then
            echo "" 
            echo "ERROR: Could not run Docker Desktop automatically. Please start it manually."
            echo "" 
            exit 1
        fi
    else
        echo ""
        echo "Docker is running"
        echo ""
    fi
}

start_podman_engine() {
    if ! podman --version > /dev/null 2>&1;
    then
        if [ "${OPEN_CONTAINERS_ENGINE_APP}" = "1" ]; then
            echo ""
            echo "ERROR: Podman is not installed... running 'brew install podman'..."
            if ! brew install podman
            then
                echo ""
                echo "ERROR: Could not install Podman automatically"
                exit 1
            fi
        else
            echo ""
            echo "ERROR: Podman is not installed... run 'brew install podman' manually."
            exit 1
        fi
    fi
    if ! podman ps > /dev/null 2>&1;
    then
        export DOCKER_WAS_NOT_RUNNING="1"
        if [ "${OPEN_CONTAINERS_ENGINE_APP}" = "1" ]; then
            if ! podman machine list | grep podman-machine-default -q
            then
                echo ""
                echo "Podman machine 'podman-machine-default' does not exist... running 'podman machine init'..."
                if ! podman machine init
                then
                    echo ""
                    echo "ERROR: Could not initialize Podman automatically"
                    exit 1
                fi
            fi
            # Start Podman
            echo ""
            echo "Starting podman machine..."
            podman machine set --rootful=true --user-mode-networking=true
            if ! podman machine start
            then
                echo "" 
                echo "ERROR: Could not run podman machine start automatically"
                exit 1
            fi
        else
            echo ""
            echo "ERROR: Podman machine 'podman-machine-default' does not exist... run 'podman machine init' manually."
            exit 1
        fi
    else
        echo "Podman is running"
        echo ""
    fi
}

ACTION="$1"
CONTAINERS_ENGINE="$2"
OPEN_CONTAINERS_ENGINE_APP="$3"

set_default_values

if [ "${ACTION}" = "start" ]; then
    echo ""
    echo "Starting containers engine '${CONTAINERS_ENGINE}'..."
    echo ""
    if [ "${CONTAINERS_ENGINE}" = "docker" ]; then
        start_docker_engine
    elif [ "${CONTAINERS_ENGINE}" = "podman" ]; then
        start_podman_engine
    fi
elif [ "${ACTION}" = "stop" ]; then
    echo ""
    echo "Stopping containers engine '${CONTAINERS_ENGINE}'..."
    echo ""
    if [ "${CONTAINERS_ENGINE}" = "docker" ]; then
        echo "There is no docker stop command"
    elif [ "${CONTAINERS_ENGINE}" = "podman" ]; then
        podman machine stop
    fi
elif [ "${ACTION}" = "restart" ]; then
    echo ""
    echo "Restarting containers engine '${CONTAINERS_ENGINE}'..."
    echo ""
    if [ "${CONTAINERS_ENGINE}" = "docker" ]; then
        echo "There is no docker restart command"
    elif [ "${CONTAINERS_ENGINE}" = "podman" ]; then
        podman machine stop
        start_podman_engine
    fi
elif [ "${ACTION}" = "status" ]; then
    echo ""
    echo "Containers engine '${CONTAINERS_ENGINE}' status:"
    echo ""
    if [ "${CONTAINERS_ENGINE}" = "docker" ]; then
        docker ps
    elif [ "${CONTAINERS_ENGINE}" = "podman" ]; then
        podman machine status
    fi
else
    echo "Invalid action: ${ACTION} or invalid containers engine: ${CONTAINERS_ENGINE}"
    exit 1
fi

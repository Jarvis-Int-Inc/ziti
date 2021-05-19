#!/bin/bash

ZITI_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ZITI_QUICKSTART_ENVROOT="${HOME}/.ziti/quickstart"
ZITI_QUICKSTART_SCRIPT_ROOT="$(realpath "${ZITI_SCRIPT_DIR}/../../")"
. "${ZITI_QUICKSTART_SCRIPT_ROOT}/ziti-cli-functions.sh"

function issueGreeting {
  #echo "-------------------------------------------------------------"
  echo " "
  echo "                          _   _     _"
  echo "                    ____ (_) | |_  (_)"
  echo "                   |_  / | | | __| | |"
  echo "                    / /  | | | |_  | |"
  echo "                   /___| |_|  \__| |_|"
  echo "-------------------------------------------------------------"
  echo " "
  echo "This script will make it trivial to setup a very simple environment locally which will allow you to start"
  echo "learning ziti. This environment is suitable for development work only and is not a decent representation of"
  echo "a fully redundant production-caliber network."
  echo ""
  echo "Please note that this script will write files to your home directory into a directory named .ziti."
  echo -n "For you this location will be: "
  echo -e "$(BLUE "${ZITI_QUICKSTART_ENVROOT}")"
  echo " "
}

function setupZitiNetwork {
  if [[ "$1" == "" ]]; then
    echo " "
    echo "Creating a controller is effectively creating a network. The name of the network will be used when writing"
    echo "configuration files locally. Choose the name of your network now. The format of the network name should resemble"
    echo -n "what a hostname looks like. A good choice is to actually use your system's hostname: "
    echo -e "$(BLUE $(hostname))"
    echo " "
    read -p "$(echo -ne "Network Name [$(BLUE $(hostname))]: ")" ZITI_NETWORK
    echo " "
    if checkControllerName; then
      : #clear to continue
      if [[ "ZITI_NETWORK" == "" ]]; then
        ZITI_NETWORK="$(hostname)"
      fi
      echo "name: ${ZITI_NETWORK}"
    else
      echo " "
      echo "nah bro"
      return 1
    fi
    echo " "
  else
    ZITI_NETWORK="$1"
  fi
}

function setupZitiHome {
  export ZITI_HOME="${HOME}/.ziti/quickstart/${ZITI_NETWORK}"
}

function generateEnvFile {

  echo -e "Generating new network with name: $(BLUE "${ZITI_NETWORK}")"

  if [[ "${ZITI_CONTROLLER_RAWNAME}" == "" ]]; then export export ZITI_CONTROLLER_RAWNAME="${ZITI_NETWORK}-controller"; fi
  if [[ "${ZITI_CONTROLLER_HOSTNAME}" == "" ]]; then export export ZITI_CONTROLLER_HOSTNAME="${ZITI_NETWORK}"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_RAWNAME}" == "" ]]; then export export ZITI_EDGE_CONTROLLER_RAWNAME="${ZITI_NETWORK}-edge-controller"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_HOSTNAME}" == "" ]]; then export export ZITI_EDGE_CONTROLLER_HOSTNAME="${ZITI_NETWORK}"; fi
  if [[ "${ZITI_ZAC_RAWNAME}" == "" ]]; then export export ZITI_ZAC_RAWNAME="${ZITI_NETWORK}"; fi
  if [[ "${ZITI_ZAC_HOSTNAME}" == "" ]]; then export export ZITI_ZAC_HOSTNAME="${ZITI_NETWORK}"; fi
  if [[ "${ZITI_EDGE_ROUTER_RAWNAME}" == "" ]]; then export export ZITI_EDGE_ROUTER_RAWNAME="${ZITI_NETWORK}-edge-router"; fi
  if [[ "${ZITI_EDGE_ROUTER_HOSTNAME}" == "" ]]; then export export ZITI_EDGE_ROUTER_HOSTNAME="${ZITI_NETWORK}"; fi
  if [[ "${ZITI_EDGE_ROUTER_PORT}" == "" ]]; then export ZITI_EDGE_ROUTER_PORT="3022"; fi

  if [[ "${ZITI_BIN_ROOT}" == "" ]]; then
    export ZITI_BIN_ROOT="${ZITI_HOME}/ziti-bin"
  fi

  export ZITI_SCRIPTS="$(realpath "${ZITI_SCRIPT_DIR}/..")"
  export ZITI_SHARED=${ZITI_HOME}
  export ENV_FILE="${ZITI_HOME}/${ZITI_NETWORK}.env"
  "${ZITI_QUICKSTART_SCRIPT_ROOT}/docker/image/env.sh"
  echo -e "environment file created and sourced from: $(BLUE "${ENV_FILE}")"
  source "${ENV_FILE}"
}

function expressConfiguration {
  echo " "
  echo "___________   _______________________________________^__"
  echo " ___   ___ |||  ___   ___   ___    ___ ___  |   __  ,----\ "
  echo "|   | |   |||| |   | |   | |   |  |   |   | |  |  | |_____\ "
  echo "|___| |___|||| |___| |___| |___|  | O | O | |  |  |        \ "
  echo "           ||| ===== EXPRESS ==== |___|___| |  |__|         )"
  echo "___________|||______________________________|______________/"
  echo "           |||                                        /--------"
  echo "-----------'''---------------------------------------'"
  echo ""

  if [[ "$1" == "" ]]; then
    nw="$(hostname)"
  else
    nw="$1"
  fi

  setupZitiNetwork "${nw}"
  setupZitiHome

  getLatestZiti "no"
  generateEnvFile
  #checkHostsFile

  generatePki
  generateControllerConfig
  initializeController
  startZitiController
  echo "starting the ziti controller to enroll the edge router"
  sleep 2

  zitiLogin

  echo -e "----------  Creating an edge router policy allowing all identities to connect to routers with a $(GREEN "#public") attribute"
  unused=$("${ZITI_BIN_DIR}/ziti" edge delete edge-router-policy allEdgeRouters)
  unused=$("${ZITI_BIN_DIR}/ziti" edge create edge-router-policy allEdgeRouters --edge-router-roles '#public' --identity-roles '#all' )

  echo -e "----------  Creating a service edge router policy allowing all services to use $(GREEN "#public") edge routers"
  unused=$("${ZITI_BIN_DIR}/ziti" edge delete service-edge-router-policy allSvcPublicRouters)
  unused=$("${ZITI_BIN_DIR}/ziti" edge create service-edge-router-policy allSvcPublicRouters --edge-router-roles '#public' --service-roles '#all')

  "${ZITI_SCRIPTS}/create-router-pki.sh"
  generateEdgeRouterConfig

  echo "----------  Creating edge-router ${ZITI_EDGE_ROUTER_RAWNAME}...."
  unused=$("${ZITI_BIN_DIR}/ziti" edge delete edge-router "${ZITI_EDGE_ROUTER_RAWNAME}")
  unused=$("${ZITI_BIN_DIR}/ziti" edge create edge-router "${ZITI_EDGE_ROUTER_RAWNAME}" -o "${ZITI_HOME}/${ZITI_EDGE_ROUTER_RAWNAME}.jwt" -t)
  sleep 1
  echo "---------- Enrolling edge-router ${ZITI_EDGE_ROUTER_RAWNAME}...."

  unused=$("${ZITI_BIN_DIR}/ziti-router" enroll "${ZITI_HOME}/${ZITI_EDGE_ROUTER_RAWNAME}.yaml" --jwt "${ZITI_HOME}/${ZITI_EDGE_ROUTER_RAWNAME}.jwt" &> "${ZITI_HOME}/${ZITI_EDGE_ROUTER_RAWNAME}.enrollment.log")
  echo ""
  sleep 1
  unused=$("${ZITI_BIN_DIR}/ziti-router" run "${ZITI_HOME}/${ZITI_EDGE_ROUTER_RAWNAME}.yaml" > "${ZITI_HOME}/${ZITI_EDGE_ROUTER_RAWNAME}.log" 2>&1 &)
}

function decideOperation {
  if [[ "$1" != "" ]]; then
    yn=$1
  fi
  while true
  do
    if [[ "${yn}" == "" ]]; then
      echo "What sort of operation are you looking to perform?"
      echo "  1.) Express configuration - a simple overlay will be spawned containing one controller and two edge routers"
      echo "  2.) Create Controller configuration - answer a few questions and a controller config will be emitted"
      echo "  3.) Create Edge Router configuration - answer a few questions and an edge router config will be emitted"
      echo "  4.) Start a network with the provided name"
      echo " "
      read -p "Select an action: " yn
    fi
    case $yn in
        [1]* )
            expressConfiguration "$2"
            break;;
        [2]* )
            generateEnvFile

            ;;
        [3]* )
            echo "333 has been chosen"
            echo " "
            ;;
        [4]* )
            echo "4444 has been chosen"
            echo " "
            ;;
        [yYqQeE]* )
            break
            ;;
        [Nn]* )
            echo ""; echo "Ok - come back when you're ready."
            exit;;
        * ) echo "Please answer yes or no. (yes/NO)";;
    esac
    yn=
  done
  echo " "
}

#greet the user with the banner and quick blurb about what to expect
issueGreeting

#make sure the user has all the necessary commands to be successful
checkPrereqs

#prompt the user for input and do what they want/need
decideOperation 1 "$1"


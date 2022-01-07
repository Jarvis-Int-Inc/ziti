#!/bin/bash

set -uo pipefail

# shellcheck disable=SC2155
export DEFAULT_ZITI_HOME_LOCATION="${HOME}/.ziti/quickstart/$(hostname)"

export ZITI_QUICKSTART_ENVROOT="${HOME}/.ziti/quickstart"

ASCI_WHITE='\033[01;37m'
ASCI_RESTORE='\033[0m'
ASCI_RED='\033[00;31m'
ASCI_GREEN='\033[00;32m'
ASCI_YELLOW='\033[00;33m'
ASCI_BLUE='\033[00;34m'
#ASCI_MAGENTA='\033[00;35m'
#ASCI_PURPLE='\033[00;35m'
#ASCI_CYAN='\033[00;36m'
#ASCI_LIGHTGRAY='\033[00;37m'
#ASCI_LRED='\033[01;31m'
#ASCI_LGREEN='\033[01;32m'
#ASCI_LYELLOW='\033[01;33m'
#ASCI_LBLUE='\033[01;34m'
#ASCI_LMAGENTA='\033[01;35m'
#ASCI_LPURPLE='\033[01;35m'
#ASCI_LCYAN='\033[01;36m'

function WHITE {
  echo "${ASCI_WHITE}${1-}${ASCI_RESTORE}"
}
function RED {
  echo "${ASCI_RED}${1-}${ASCI_RESTORE}"
}
function GREEN {
  echo "${ASCI_GREEN}${1-}${ASCI_RESTORE}"
}
function YELLOW {
  echo "${ASCI_YELLOW}${1-}${ASCI_RESTORE}"
}
function BLUE {
  echo "${ASCI_BLUE}${1-}${ASCI_RESTORE}"
}

function zitiLogin {
  "${ZITI_BIN_DIR-}/ziti" edge login "${ZITI_EDGE_CONTROLLER_API}" -u "${ZITI_USER-}" -p "${ZITI_PWD}" -c "${ZITI_PKI_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_ROOTCA_NAME}/certs/${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}.cert"
}
function cleanZitiController {
  checkEnvVariable ZITI_HOME
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi
  rm -rf "${ZITI_HOME}/db"
  mkdir "${ZITI_HOME}/db"
  initializeController
}
function initializeController {
"${ZITI_BIN_DIR-}/ziti-controller" edge init "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_RAWNAME}.yaml" -u "${ZITI_USER-}" -p "${ZITI_PWD}" &> "${ZITI_HOME_OS_SPECIFIC}/controller-init.log"
  echo -e "ziti-controller initialized. see $(BLUE "${ZITI_HOME-}/${ZITI_EDGE_CONTROLLER_RAWNAME}-init.log") for details"
}
function startZitiController {
  # shellcheck disable=SC2034
  ("${ZITI_BIN_DIR-}/ziti-controller" run "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_RAWNAME}.yaml" > "${ZITI_HOME_OS_SPECIFIC}/ziti-edge-controller.log" 2>&1 &)
  pid=$!
  echo -e "ziti-controller started as process id: $pid. log located at: $(BLUE "${ZITI_HOME-}/${ZITI_EDGE_CONTROLLER_RAWNAME}.log")"
  return $pid
}

function stopZitiController {
  killall ziti-controller
  # shellcheck disable=SC2181
  if [[ $? == 0 ]]; then echo "Controller stopped."; fi
}

function startExpressEdgeRouter {
  "${ZITI_BIN_DIR}/ziti-router" run "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.yaml" > "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.log" 2>&1 &
  pid=$!
  echo -e "Express Edge Router started as process id: $pid. log located at: $(BLUE "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.log")"
  return $pid
}

function stopAllEdgeRouters {
  killall ziti-router
  # shellcheck disable=SC2181
  if [[ $? == 0 ]]; then echo "Router(s) stopped."; fi
}

function checkHostsFile {
  ctrlexists=$(grep -c "${ZITI_CONTROLLER_HOSTNAME}" /etc/hosts)
  edgectrlexists=$(grep -c "${ZITI_EDGE_CONTROLLER_HOSTNAME}" /etc/hosts)
  erexists=$(grep -c "${ZITI_EDGE_ROUTER_HOSTNAME}" /etc/hosts)

  if [[ "0" = "${ctrlexists}" ]] || [[ "0" = "${edgectrlexists}" ]] || [[ "0" = "${erexists}" ]]; then
    echo " "
    echo -e "$(YELLOW "Ziti is generally used to create an overlay network. Generally speaking this will involve more than one host")"
    echo -e "$(YELLOW "Since this is a script geared towards setting up a very minimal development environment it needs to make some")"
    echo -e "$(YELLOW "assumptions. One of these assumptions is that the three specific entries are entered onto your hosts file.")"
    echo -e "$(YELLOW "One or more of these are missing:")"
    echo " "
    if [[ "0" == "${ctrlexists}" ]]; then
      echo -e "  * $(RED "MISSING: ${ZITI_EDGE_CONTROLLER_HOSTNAME}") "
    else
      echo -e "  * $(GREEN "  FOUND: ${ZITI_EDGE_CONTROLLER_HOSTNAME}") "
    fi
    if [[ "0" == "${edgectrlexists}" ]]; then
      echo -e "  * $(RED "MISSING: ${ZITI_EDGE_CONTROLLER_HOSTNAME}") "
    else
      echo -e "  * $(GREEN "  FOUND: ${ZITI_EDGE_CONTROLLER_HOSTNAME}") "
    fi
    if [[ "0" == "${erexists}" ]]; then
      echo -e "  * $(RED "MISSING: ${ZITI_EDGE_ROUTER_HOSTNAME}") "
    else
      echo -e "  * $(GREEN "  FOUND: ${ZITI_EDGE_ROUTER_HOSTNAME}") "
    fi

    echo " "
    echo "The easiest way to correct this is to run the following command:"
    echo "  echo \"127.0.0.1 ${ZITI_CONTROLLER_HOSTNAME} ${ZITI_EDGE_CONTROLLER_HOSTNAME} ${ZITI_EDGE_ROUTER_HOSTNAME}\" | sudo tee -a /etc/hosts"
    echo " "
    echo "add these entries to your hosts file, and rerun the script when ready"
    return 1
  else
    echo -e "$(GREEN "Hosts file looks good")"
  fi
}

function getLatestZitiVersion {
  setupZitiHome

  if ! setOs; then
    return 1
  fi

  ZITI_ARCH="amd64"
  if [[ "$(uname -a)" == *"arm"* ]]; then
    ZITI_ARCH="arm"
  fi

  unset ZITI_BINARIES_VERSION

  if [[ "${ZITI_BINARIES_VERSION-}" == "" ]]; then
    zitilatest=$(curl -s https://api.github.com/repos/openziti/ziti/releases/latest)
    # shellcheck disable=SC2155
    export ZITI_BINARIES_FILE=$(echo "${zitilatest}" | tr '\r\n' ' ' | jq -r '.assets[] | select(.name | startswith("'"ziti-${ZITI_OSTYPE}-${ZITI_ARCH}"'")) | .name')
    # shellcheck disable=SC2155
    export ZITI_BINARIES_VERSION=$(echo "${zitilatest}" | tr '\r\n' ' ' | jq -r '.tag_name')
  fi
  echo "ZITI_BINARIES_VERSION: ${ZITI_BINARIES_VERSION}"
}

function getLatestZiti {
  setupZitiHome
  checkEnvVariable ZITI_HOME
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

  ziti_bin_root="${ZITI_BIN_ROOT-}"
  if [[ "${ziti_bin_root}" == "" ]]; then
    ziti_bin_root="${ZITI_HOME-}/ziti-bin"
  fi
  export ZITI_BIN_ROOT="${ziti_bin_root}/ziti-bin"

  mkdir -p "${ziti_bin_root}"

  if ! getLatestZitiVersion; then
    return 1
  fi

  export ZITI_BIN_DIR="${ziti_bin_root}/ziti-${ZITI_BINARIES_VERSION}"

  ZITI_BINARIES_FILE_ABSPATH="${ZITI_HOME-}/ziti-bin/${ZITI_BINARIES_FILE}"
  if ! test -f "${ZITI_BINARIES_FILE_ABSPATH}"; then
    zitidl="https://github.com/openziti/ziti/releases/download/${ZITI_BINARIES_VERSION-}/${ZITI_BINARIES_FILE}"
    echo -e 'Downloading '"$(BLUE "${zitidl}")"' to '"$(BLUE "${ZITI_BINARIES_FILE_ABSPATH}")"
    curl -Ls "${zitidl}" -o "${ZITI_BINARIES_FILE_ABSPATH}"
  else
    echo -e "$(YELLOW 'Already Downloaded ')""$(BLUE "${ZITI_BINARIES_FILE}")"' at: '"${ZITI_BINARIES_FILE_ABSPATH}"
  fi

  echo -e 'UNZIPPING '"$(BLUE "${ZITI_BINARIES_FILE_ABSPATH}")"' into: '"$(GREEN "${ZITI_BIN_DIR}")"
  rm -rf "${ziti_bin_root}/ziti-${ZITI_BINARIES_VERSION-}"
  if [[ "${ZITI_OSTYPE}" == "windows" ]]; then
    unzip "${ZITI_BINARIES_FILE_ABSPATH}" -d "${ZITI_BIN_DIR}"
    mv  "${ZITI_BIN_DIR}/ziti/"*  "${ZITI_BIN_DIR}/"
    rm -rf "${ZITI_BIN_DIR}/ziti/"*
    rmdir "${ZITI_BIN_DIR}/ziti/"
    chmod +x "${ZITI_BIN_DIR}/"*
  else
    tar -xf "${ZITI_BINARIES_FILE_ABSPATH}" --directory "${ziti_bin_root}"
    mv "${ziti_bin_root}/ziti" "${ZITI_BIN_DIR}"
  fi

  echo -e 'Marking executables at '"$(GREEN "${ZITI_BIN_DIR}")"' executable'
  chmod +x "${ZITI_BIN_DIR}/"*

  if [[ "${1-}" == "yes" ]]; then
    echo "Adding ${ZITI_BIN_DIR} to the path if necessary:"
    if [[ "$(echo "$PATH"|grep -q "${ZITI_BIN_DIR}" && echo "yes")" == "yes" ]]; then
      echo -e "$(GREEN "${ZITI_BIN_DIR}") is already on the path"
    else
      echo -e "adding $(RED "${ZITI_BIN_DIR}") to the path"
      export PATH=$PATH:"${ZITI_BIN_DIR}"
    fi
  fi
}

function checkPrereqs {
  commands_to_test=(curl jq)
  missing_requirements=""
  # verify all the commands required in the automation exist before trying to run the full suite
  for cmd in "${commands_to_test[@]}"
  do
      # checking all commands are on the path before continuing...
      if ! [[ -x "$(command -v "${cmd}")" ]]; then
          missing_requirements="${missing_requirements}    * ${cmd}"
      fi
  done
  # are requirements ? if yes, stop here and help 'em out
  if ! [[ "" = "${missing_requirements}" ]]; then
      echo " "
      echo "You're missing one or more commands that are used in this script."
      echo "Please ensure the commands listed are on the path and then try again."
      echo "${missing_requirements}"
      echo " "
      echo " "
      return 1
  else
    echo -e "$(GREEN "Prerequisites confirmed")"
  fi
}

function checkControllerName {
  if [[ "${ZITI_EDGE_CONTROLLER_HOSTNAME}" == *['!'@#\$%^\&*\(\)_+]* ]]; then
    echo -e "$(RED "  - The provided Network name contains an invalid character: '!'@#\$%^\&*()_+")"
    return 1
  fi
  return 0
}

function unsetZitiEnv {
  if [[ "${1-}" == "-s" ]]; then
    # Silent...
    for zEnvVar in $(set | grep -e "^ZITI_" | sort); do envvar="$(echo "${zEnvVar}" | cut -d '=' -f1)"; unset "${envvar}"; done
  else
    for zEnvVar in $(set | grep -e "^ZITI_" | sort); do envvar="$(echo "${zEnvVar}" | cut -d '=' -f1)"; echo unsetting "[${envvar}]${zEnvVar}"; unset "${envvar}"; done
  fi
  unset ZITIx_EXPRESS_COMPLETE
}

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
  if [[ "${1-}" == "" ]]; then
    echo " "
    echo "Creating a controller is effectively creating a network. The name of the network will be used when writing"
    echo "configuration files locally. Choose the name of your network now. The format of the network name should resemble"
    echo -n "what a hostname looks like. A good choice is to actually use your system's hostname: "
    echo -e "$(BLUE "$(hostname)")"
    echo " "
    echo -en "$(echo -ne "Network Name [$(BLUE "$(hostname)")]: ")"
    read -r ZITI_NETWORK
    echo " "
    if checkControllerName; then
      : #clear to continue
      if [[ "${ZITI_NETWORK-}" == "" ]]; then
        ZITI_NETWORK="$(hostname)"
      fi
      echo "name: ${ZITI_NETWORK-}"
    else
      echo ""
      echo "============ FAILED TO SETUP NETWORK ============"
      return 1
    fi
    echo " "
  else
    ZITI_NETWORK="${1-}"
  fi
}

function setupZitiHome {
  if [[ "${ZITI_HOME-}" == "" ]]; then
    export ZITI_HOME="${HOME}/.ziti/quickstart/${ZITI_NETWORK-}"
    echo -e "using default ZITI_HOME: $(BLUE "${ZITI_HOME}")"
  fi
}

function generateEnvFile {

  echo -e "Generating new network with name: $(BLUE "${ZITI_NETWORK-}")"

  if [[ "${ZITI_CONTROLLER_RAWNAME-}" == "" ]]; then export export ZITI_CONTROLLER_RAWNAME="${ZITI_NETWORK-}-controller"; fi
  if [[ "${ZITI_CONTROLLER_HOSTNAME-}" == "" ]]; then export export ZITI_CONTROLLER_HOSTNAME="${ZITI_NETWORK-}"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_RAWNAME-}" == "" ]]; then export export ZITI_EDGE_CONTROLLER_RAWNAME="${ZITI_NETWORK-}-edge-controller"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_HOSTNAME-}" == "" ]]; then export export ZITI_EDGE_CONTROLLER_HOSTNAME="${ZITI_NETWORK-}"; fi
  if [[ "${ZITI_ZAC_RAWNAME-}" == "" ]]; then export export ZITI_ZAC_RAWNAME="${ZITI_NETWORK-}"; fi
  if [[ "${ZITI_ZAC_HOSTNAME-}" == "" ]]; then export export ZITI_ZAC_HOSTNAME="${ZITI_NETWORK-}"; fi
  if [[ "${ZITI_EDGE_ROUTER_RAWNAME-}" == "" ]]; then export export ZITI_EDGE_ROUTER_RAWNAME="${ZITI_NETWORK-}-edge-router"; fi
  if [[ "${ZITI_EDGE_ROUTER_HOSTNAME-}" == "" ]]; then export export ZITI_EDGE_ROUTER_HOSTNAME="${ZITI_NETWORK-}"; fi
  if [[ "${ZITI_EDGE_ROUTER_PORT-}" == "" ]]; then export ZITI_EDGE_ROUTER_PORT="3022"; fi

  if [[ "${ZITI_BIN_ROOT-}" == "" ]]; then
    export ZITI_BIN_ROOT="${ZITI_HOME-}/ziti-bin"
  fi

  if ! ziti_createEnvFile; then
    return 1
  fi

  export ENV_FILE="${ZITI_HOME-}/${ZITI_NETWORK-}.env"

  echo -e "environment file sourced from: $(BLUE "${ENV_FILE}")"
}

function ziti_expressConfiguration {
  if [[ "${ZITIx_EXPRESS_COMPLETE-}" != "" ]]; then
    echo -e "$(RED "  --- It looks like you've run an express install in this shell already. ---")"
    echo -en "Would you like to clear existing Ziti variables and continue (y/N)? "
    read -r
    echo " "
    if [[ "${REPLY}" == [Yy]* ]]; then
      echo -e "$(GREEN "Clearing existing Ziti variables and continuing with express install")"
      unsetZitiEnv "-s"
    else
      echo -e "$(RED "  --- Exiting express install ---")"
      return 1
    fi
  fi
  export ZITIx_EXPRESS_COMPLETE="true"
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
  if [[ "${ZITI_CONTROLLER_RAWNAME-}" != "" ]]; then echo "ZITI_CONTROLLER_RAWNAME OVERRIDDEN: $ZITI_CONTROLLER_RAWNAME"; fi
  if [[ "${ZITI_CONTROLLER_HOSTNAME-}" != "" ]]; then echo "ZITI_CONTROLLER_HOSTNAME OVERRIDDEN: $ZITI_CONTROLLER_HOSTNAME"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_RAWNAME-}" != "" ]]; then echo "ZITI_EDGE_CONTROLLER_RAWNAME OVERRIDDEN: $ZITI_EDGE_CONTROLLER_RAWNAME"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_HOSTNAME-}" != "" ]]; then echo "ZITI_EDGE_CONTROLLER_HOSTNAME OVERRIDDEN: $ZITI_EDGE_CONTROLLER_HOSTNAME"; fi
  if [[ "${ZITI_ZAC_RAWNAME-}" != "" ]]; then echo "ZITI_ZAC_RAWNAME OVERRIDDEN: $ZITI_ZAC_RAWNAME"; fi
  if [[ "${ZITI_ZAC_HOSTNAME-}" != "" ]]; then echo "ZITI_ZAC_HOSTNAME OVERRIDDEN: $ZITI_ZAC_HOSTNAME"; fi
  if [[ "${ZITI_EDGE_ROUTER_RAWNAME-}" != "" ]]; then echo "ZITI_EDGE_ROUTER_RAWNAME OVERRIDDEN: $ZITI_EDGE_ROUTER_RAWNAME"; fi
  if [[ "${ZITI_EDGE_ROUTER_HOSTNAME-}" != "" ]]; then echo "ZITI_EDGE_ROUTER_HOSTNAME OVERRIDDEN: $ZITI_EDGE_ROUTER_HOSTNAME"; fi
  if [[ "${ZITI_EDGE_ROUTER_PORT-}" != "" ]]; then echo "ZITI_EDGE_ROUTER_PORT OVERRIDDEN: $ZITI_EDGE_ROUTER_PORT"; fi

  echo " "
  echo " "
  echo -e "******** Setting Up Environment ********"
  if [[ "${1-}" == "" ]]; then
    nw="$(hostname)"
  else
    nw="${1-}"
  fi

  setupZitiNetwork "${nw}"
  setupZitiHome
  echo -e "ZITI HOME SET TO: $(BLUE "${ZITI_HOME}")"

  if ! getLatestZiti "no"; then
    echo -e "$(RED "getLatestZiti failed")"
    return 1
  fi
  if ! generateEnvFile; then
    echo "Exiting as env file was not generated"
    return 1
  fi
  #checkHostsFile

  echo " "
  echo " "
  echo -e "******** Setting Up Public Key Infrastructure ********"
  createPki

  echo " "
  echo " "
  echo -e "******** Setting Up Controller ********"
  createControllerConfig
  #createControllerSystemdFile
  initializeController
  startZitiController
  echo "waiting for the controller to come online to allow the edge router to enroll"
  waitForController

  zitiLogin

  echo " "
  echo " "
  echo -e "******** Setting Up Edge Routers ********"
  echo -e "----------  Creating an edge router policy allowing all identities to connect to routers with a $(GREEN "#public") attribute"
  "${ZITI_BIN_DIR-}/ziti" edge delete edge-router-policy allEdgeRouters > /dev/null
  "${ZITI_BIN_DIR-}/ziti" edge create edge-router-policy allEdgeRouters --edge-router-roles '#public' --identity-roles '#all' > /dev/null

  echo -e "----------  Creating a service edge router policy allowing all services to use $(GREEN "#public") edge routers"
  "${ZITI_BIN_DIR-}/ziti" edge delete service-edge-router-policy allSvcPublicRouters > /dev/null
  "${ZITI_BIN_DIR-}/ziti" edge create service-edge-router-policy allSvcPublicRouters --edge-router-roles '#public' --service-roles '#all' > /dev/null

  createRouterPki
  createEdgeRouterConfig "${ZITI_EDGE_ROUTER_RAWNAME}"
  #createRouterSystemdFile "${ZITI_EDGE_ROUTER_RAWNAME}"

  echo "----------  Creating edge-router ${ZITI_EDGE_ROUTER_RAWNAME}...."
  "${ZITI_BIN_DIR-}/ziti" edge delete edge-router "${ZITI_EDGE_ROUTER_RAWNAME}" > /dev/null
  "${ZITI_BIN_DIR-}/ziti" edge create edge-router "${ZITI_EDGE_ROUTER_RAWNAME}" -o "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.jwt" -t -a "public"> /dev/null
  sleep 1
  echo "----------  Enrolling edge-router ${ZITI_EDGE_ROUTER_RAWNAME}...."

  "${ZITI_BIN_DIR-}/ziti-router" enroll "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.yaml" --jwt "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.jwt" &> "${ZITI_HOME_OS_SPECIFIC}/${ZITI_EDGE_ROUTER_RAWNAME}.enrollment.log"
  echo ""

  stopZitiController
  echo "Edge Router enrolled. Controller stopped."

  echo ""
  echo -e "$(GREEN "Congratulations. Express setup complete!")"
  echo -e "Start your Ziti Controller by running the function: $(BLUE "startZitiController")"
  echo -e "Start your Ziti Edge Router by running : $(BLUE 'startExpressEdgeRouter')"
  echo ""
}

function decideToUseDefaultZitiHome {
  yn=""
  while true
  do
    echo "ZITI_HOME has not been set. Do you want to use the default ZITI_HOME: ${DEFAULT_ZITI_HOME_LOCATION}"
    echo " "
    echo -en "Select an action: "
    read -r yn
    case $yn in
        [yY]* )
            ZITI_HOME="${DEFAULT_ZITI_HOME_LOCATION}"
            break;;
        [Nn]* )
            echo ""
            return 1;;
        * )
            echo " "
            echo "Answer $yn is not valid. Please answer yes or no. (y/n [yes/NO])";;
    esac
    yn=
  done
  echo " "
}

function decideOperation {
  yn="${1-}"
  while true
  do
    if [[ "${yn}" == "" ]]; then
      echo "What sort of operation are you looking to perform?"
      echo "  1.) Express configuration - a simple overlay will be spawned containing one controller and two edge routers"
      echo "  2.) Create Controller configuration - answer a few questions and a controller config will be emitted"
      echo "  3.) Create Edge Router configuration - answer a few questions and an edge router config will be emitted"
      echo "  4.) Start a network with the provided name"
      echo " "
      echo -en "Select an action: "
      read -r yn
    fi
    case $yn in
        [1]* )
            ziti_expressConfiguration "$2"
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

function expressInstall {
  #greet the user with the banner and quick blurb about what to expect
  issueGreeting

  #make sure the user has all the necessary commands to be successful
  checkPrereqs
  retval=$?
  if [ $retval -ne 0 ]; then
    return 1
  fi
  echo "Let's get started creating your local development network!"
  echo ""
  echo ""

  #prompt the user for input and do what they want/need
  decideOperation 1 "${1-}"
}

function pki_client_server {
  name_local=${1-}
  ZITI_CA_NAME_local=$2
  ip_local=$3

  if [[ "${ip_local}" == "" ]]; then
    ip_local="127.0.0.1"
  fi

  if ! test -f "${ZITI_PKI}/${ZITI_CA_NAME_local}/keys/${name_local}-server.key"; then
    echo "Creating server cert from ca: ${ZITI_CA_NAME_local} for ${name_local}"
    "${ZITI_BIN_DIR-}/ziti" pki create server --pki-root="${ZITI_PKI_OS_SPECIFIC}" --ca-name "${ZITI_CA_NAME_local}" \
          --server-file "${name_local}-server" \
          --dns "${name_local},localhost" --ip "${ip_local}" \
          --server-name "${name_local} server certificate"
  else
    echo "Creating server cert from ca: ${ZITI_CA_NAME_local} for ${name_local}"
    echo "key exists"
  fi

  if ! test -f "${ZITI_PKI}/${ZITI_CA_NAME_local}/keys/${name_local}-client.key"; then
    echo "Creating client cert from ca: ${ZITI_CA_NAME_local} for ${name_local}"
    "${ZITI_BIN_DIR-}/ziti" pki create client --pki-root="${ZITI_PKI_OS_SPECIFIC}" --ca-name "${ZITI_CA_NAME_local}" \
          --client-file "${name_local}-client" \
          --key-file "${name_local}-server" \
          --client-name "${name_local}"
  else
    echo "Creating client cert from ca: ${ZITI_CA_NAME_local} for ${name_local}"
    echo "key exists"
  fi
  echo " "
}

function pki_create_ca {
  cert=$1

  echo "Creating CA: ${cert}"
  if ! test -f "${ZITI_PKI}/${cert}/keys/${cert}.key"; then
    "${ZITI_BIN_DIR}/ziti" pki create ca --pki-root="${ZITI_PKI_OS_SPECIFIC}" --ca-file="${cert}" --ca-name="${cert} Root CA"
  else
    echo "key exists"
  fi
  echo " "
}

function pki_create_intermediate {
  echo "Creating intermediate: ${1} ${2} ${3}"
  if ! test -f "${ZITI_PKI}/${2}/keys/${2}.key"; then
    "${ZITI_BIN_DIR}/ziti" pki create intermediate --pki-root "${ZITI_PKI_OS_SPECIFIC}" --ca-name "${1}" \
          --intermediate-name "${2}" \
          --intermediate-file "${2}" --max-path-len "${3}"
  else
    echo "key exists"
  fi
  echo " "
}
function printUsage() {
    echo "Usage: ${1-} [cert to test] [ca pool to use]"
}

function verifyCertAgainstPool() {
  if [[ "" == "${1-}" ]]
  then
      printUsage "verifyCertAgainstPool"
      return 1
  fi

  if [[ "" == "$2" ]]
  then
      printUsage "verifyCertAgainstPool"
      return 1
  fi

  echo "    Verifying that this certificate:"
  echo "        - ${1-}"
  echo "    is valid for this ca pool:"
  echo "        - $2"
  echo ""
  openssl verify -partial_chain -CAfile "$2" "${1-}"
  # shellcheck disable=SC2181
  if [ $? -eq 0 ]; then
      echo ""
      echo "============      SUCCESS!      ============"
  else
      echo ""
      echo "============ FAILED TO VALIDATE ============"
  fi
}

function showIssuerAndSubjectForPEM() {
  echo "Displaying Issuer and Subject for cert pool:"
  echo "    ${1-}"
  openssl crl2pkcs7 -nocrl -certfile "${1-}" | openssl pkcs7 -print_certs -text -noout | grep -E "(Subject|Issuer)"
}

function createRouterPki {
  pki_client_server "${ZITI_EDGE_ROUTER_RAWNAME}" "${ZITI_CONTROLLER_INTERMEDIATE_NAME}" "${ZITI_EDGE_ROUTER_IP_OVERRIDE-}"
}

function createPrivateRouterConfig {
  # Allow router name to be passed in as arg
  router_name="${1-}"
  if [[ "${router_name}" == "" ]]; then

    # If router name is not passed as arg, prompt user for input
    echo -e "$(YELLOW "createPrivateRouterConfig requires a router name to be supplied") "
    default_router_name="${ZITI_EDGE_ROUTER_RAWNAME}"
    echo -en "Enter router name (${default_router_name}):"
    read -r router_name

    # Accept the default if no name provided
    if [[ "${router_name}" == "" ]]; then
      # Check for overwrite of default file
      router_name="${default_router_name}"
      if [[ -f "${ZITI_HOME-}/${router_name}.yaml" ]]; then
        echo -en "This will overwrite the existing file, continue (y/N)? "
        read -r
        echo " ${REPLY}"
        if [[ "${REPLY}" == [^Yy]* ]]; then
          echo -e "$(RED "  --- Cancelling overwrite ---")"
          return 1
        fi
      fi
    fi
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME-}/${router_name}.yaml"
cat > "${output_file}" <<HereDocForEdgeRouter
v: 3

identity:
  cert:                 "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-client.cert"
  server_cert:          "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-server.cert"
  key:                  "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${router_name}-server.key"
  ca:                   "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-cas.cert"

ctrl:
  endpoint:             tls:${ZITI_CONTROLLER_HOSTNAME}:${ZITI_FAB_CTRL_PORT}

link:
#  listeners:
#    - binding:          transport
#      bind:             tls:0.0.0.0:10080
#      advertise:        tls:${ZITI_EDGE_ROUTER_HOSTNAME}:10080
#      options:
#        outQueueSize:   16
  dialers:
    - binding: transport

listeners:
#  - binding: tunnel
#    options:
#      mode: host #tproxy|tun|host
#  - binding: transport
#    address: tls:0.0.0.0:${ZITI_EDGE_ROUTER_PORT}
#    options:
#      advertise: ${ZITI_EDGE_ROUTER_HOSTNAME}:${ZITI_EDGE_ROUTER_PORT}
#      connectTimeoutMs: 5000
#      getSessionTimeout: 60s

#edge:
csr:
  country: US
  province: NC
  locality: Charlotte
  organization: NetFoundry
  organizationalUnit: Ziti
  sans:
    dns:
      - ${ZITI_EDGE_ROUTER_HOSTNAME}
      - localhost
    ip:
      - "127.0.0.1"

#transport:
#  ws:
#    writeTimeout:      10
#    readTimeout:       5
#    idleTimeout:       5
#    pongTimeout:       60
#    pingInterval:      54
#    handshakeTimeout:  10
#    readBufferSize:    4096
#    writeBufferSize:   4096
#    enableCompression: true
#    server_cert:       ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_WSS_ROUTER_HOSTNAME-}-router-server.cert
#    key:               ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_EDGE_WSS_ROUTER_HOSTNAME-}-router-server.key

forwarder:
  latencyProbeInterval: 1000
  xgressDialQueueLength: 1000
  xgressDialWorkerCount: 128
  linkDialQueueLength: 1000
  linkDialWorkerCount: 10
HereDocForEdgeRouter

echo -e "Controller configuration file written to: $(BLUE "${output_file}")"
}

function createPki {
  echo "Generating PKI"

  pki_create_ca "${ZITI_CONTROLLER_ROOTCA_NAME}"
  pki_create_ca "${ZITI_EDGE_CONTROLLER_ROOTCA_NAME}"
  pki_create_ca "${ZITI_SIGNING_ROOTCA_NAME}"

  ZITI_SPURIOUS_INTERMEDIATE="${ZITI_SIGNING_INTERMEDIATE_NAME}_spurious_intermediate"
  pki_create_intermediate "${ZITI_CONTROLLER_ROOTCA_NAME}" "${ZITI_CONTROLLER_INTERMEDIATE_NAME}" 1
  pki_create_intermediate "${ZITI_EDGE_CONTROLLER_ROOTCA_NAME}" "${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}" 1
  pki_create_intermediate "${ZITI_SIGNING_ROOTCA_NAME}" "${ZITI_SPURIOUS_INTERMEDIATE}" 2
  pki_create_intermediate "${ZITI_SPURIOUS_INTERMEDIATE}" "${ZITI_SIGNING_INTERMEDIATE_NAME}" 1

  if ! test -f "${ZITI_PKI}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_NETWORK-}-dotzeet.key"; then
    echo "Creating ziti-fabric client certificate for network: ${ZITI_NETWORK-}"
    "${ZITI_BIN_DIR-}/ziti" pki create client --pki-root="${ZITI_PKI_OS_SPECIFIC}" --ca-name="${ZITI_CONTROLLER_INTERMEDIATE_NAME}" \
          --client-file="${ZITI_NETWORK-}-dotzeet" \
          --client-name "${ZITI_NETWORK-} Management"
  else
    echo "Creating ziti-fabric client certificate for network: ${ZITI_NETWORK-}"
    echo "key exists"
  fi
  echo " "

  pki_client_server "${ZITI_CONTROLLER_HOSTNAME}" "${ZITI_CONTROLLER_INTERMEDIATE_NAME}" "${ZITI_CONTROLLER_IP_OVERRIDE-}"
  pki_client_server "${ZITI_EDGE_CONTROLLER_HOSTNAME}" "${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}" "${ZITI_EDGE_CONTROLLER_IP_OVERRIDE-}"

}



function createFabricRouterConfig {
  # Allow router name to be passed in as arg
  router_name="${1-}"
  if [[ "${router_name}" == "" ]]; then

    # If router name is not passed as arg, prompt user for input
    echo -e "$(YELLOW "createFabricRouterConfig requires a router name to be supplied") "
    default_router_name="${ZITI_EDGE_ROUTER_RAWNAME}"
    echo -en "Enter router name (${default_router_name}):"
    read -r router_name

    # Accept the default if no name provided
    if [[ "${router_name}" == "" ]]; then
      # Check for overwrite of default file
      router_name="${default_router_name}"
      getFileOverwritePermission "${ZITI_HOME-}/${router_name}.yaml"
      retVal=$?
      if [[ "${retVal}" != 0 ]]; then
        return 1
      fi
    fi
  fi

  checkEnvVariable ZITI_HOME
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME}/${router_name}.yaml"
cat > "${output_file}" <<HereDocForEdgeRouter
v: 3

identity:
  cert:                 "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-client.cert"
  server_cert:          "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-server.cert"
  key:                  "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${router_name}-server.key"
  ca:                   "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-cas.cert"

ctrl:
  endpoint:             tls:${ZITI_CONTROLLER_HOSTNAME}:${ZITI_FAB_CTRL_PORT}

link:
  listeners:
    - binding:          transport
      bind:             tls:0.0.0.0:10080
      advertise:        tls:${ZITI_EDGE_ROUTER_HOSTNAME}:10080
      options:
        outQueueSize:   16
  dialers:
    - binding: transport

listeners:
#  - binding: tunnel
#    options:
#      mode: host #tproxy|tun|host
  - binding: transport
    address: tls:0.0.0.0:${ZITI_EDGE_ROUTER_PORT}
    options:
      advertise: ${ZITI_EDGE_ROUTER_HOSTNAME}:${ZITI_EDGE_ROUTER_PORT}
      connectTimeoutMs: 5000
      getSessionTimeout: 60s

#edge:
csr:
  country: US
  province: NC
  locality: Charlotte
  organization: NetFoundry
  organizationalUnit: Ziti
  sans:
    dns:
      - ${ZITI_EDGE_ROUTER_HOSTNAME}
      - localhost
    ip:
      - "127.0.0.1"

#transport:
#  ws:
#    writeTimeout:      10
#    readTimeout:       5
#    idleTimeout:       5
#    pongTimeout:       60
#    pingInterval:      54
#    handshakeTimeout:  10
#    readBufferSize:    4096
#    writeBufferSize:   4096
#    enableCompression: true
#    server_cert:       ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_WSS_ROUTER_HOSTNAME-}-router-server.cert
#    key:               ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_EDGE_WSS_ROUTER_HOSTNAME-}-router-server.key

forwarder:
  latencyProbeInterval: 1000
  xgressDialQueueLength: 1000
  xgressDialWorkerCount: 128
  linkDialQueueLength: 1000
  linkDialWorkerCount: 10
HereDocForEdgeRouter

echo -e "Fabric router configuration file written to: $(BLUE "${output_file}")"
}

function createEdgeRouterWssConfig {
  # Allow router name to be passed in as arg
  router_name="${1-}"
  if [[ "${router_name}" == "" ]]; then

    # If router name is not passed as arg, prompt user for input
    echo -e "$(YELLOW "createEdgeRouterWssConfig requires a router name to be supplied") "
    default_router_name="${ZITI_EDGE_ROUTER_RAWNAME}"
    echo -en "Enter router name (${default_router_name}):"
    read -r router_name

    # Accept the default if no name provided
    if [[ "${router_name}" == "" ]]; then
      # Check for overwrite of default file
      router_name="${default_router_name}"
      getFileOverwritePermission "${ZITI_HOME-}/${router_name}.yaml"
      retVal=$?
      if [[ "${retVal}" != 0 ]]; then
        return 1
      fi
    fi
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME-}/${router_name}.yaml"
cat > "${output_file}" <<HereDocForEdgeRouter
v: 3

identity:
  cert:                 "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-client.cert"
  server_cert:          "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-server.cert"
  key:                  "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${router_name}-server.key"
  ca:                   "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-cas.cert"

ctrl:
  endpoint:             tls:${ZITI_CONTROLLER_HOSTNAME}:${ZITI_FAB_CTRL_PORT}

link:
  listeners:
    - binding:          transport
      bind:             tls:0.0.0.0:10080
      advertise:        tls:${ZITI_EDGE_ROUTER_HOSTNAME}:10080
      options:
        outQueueSize:   16
  dialers:
    - binding: transport

listeners:
  - binding: tunnel
    options:
      mode: host #tproxy|tun|host
  - binding: edge
    address: ws:0.0.0.0:3023
    options:
      advertise: ${ZITI_EDGE_ROUTER_HOSTNAME}:3023
      connectTimeoutMs: 5000
      getSessionTimeout: 60s

edge:
  csr:
    country: US
    province: NC
    locality: Charlotte
    organization: NetFoundry
    organizationalUnit: Ziti
    sans:
      dns:
        - ${ZITI_EDGE_ROUTER_HOSTNAME}
        - localhost
      ip:
        - "127.0.0.1"

transport:
  ws:
    writeTimeout:      10
    readTimeout:       5
    idleTimeout:       5
    pongTimeout:       60
    pingInterval:      54
    handshakeTimeout:  10
    readBufferSize:    4096
    writeBufferSize:   4096
    enableCompression: true
    server_cert:       ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_ROUTER_HOSTNAME}-router-server.cert
    key:               ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_EDGE_ROUTER_HOSTNAME}-router-server.key

forwarder:
  latencyProbeInterval: 1000
  xgressDialQueueLength: 1000
  xgressDialWorkerCount: 128
  linkDialQueueLength: 1000
  linkDialWorkerCount: 10
HereDocForEdgeRouter

echo -e "Edge router wss configuration file written to: $(BLUE "${output_file}")"
}

# shellcheck disable=SC2120
function createEdgeRouterConfig {
  # Allow router name to be passed in as arg
  router_name="${1-}"
  if [[ "${router_name}" == "" ]]; then

    # If router name is not passed as arg, prompt user for input
    echo -e "$(YELLOW "createEdgeRouterConfig requires a router name to be supplied") "
    default_router_name="${ZITI_EDGE_ROUTER_RAWNAME}"
    echo -en "Enter router name (${default_router_name}):"
    read -r router_name

    # Accept the default if no name provided
    if [[ "${router_name}" == "" ]]; then
      # Check for overwrite of default file
      router_name="${default_router_name}"
      getFileOverwritePermission "${ZITI_HOME-}/${router_name}.yaml"
      retVal=$?
      if [[ "${retVal}" != 0 ]]; then
        return 1
      fi
    fi
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME}/${router_name}.yaml"
cat > "${output_file}" <<HereDocForEdgeRouter
v: 3

identity:
  cert:                 "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-client.cert"
  server_cert:          "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-server.cert"
  key:                  "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${router_name}-server.key"
  ca:                   "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${router_name}-cas.cert"

ctrl:
  endpoint:             tls:${ZITI_CONTROLLER_HOSTNAME}:${ZITI_FAB_CTRL_PORT}

link:
  listeners:
    - binding:          transport
      bind:             tls:0.0.0.0:10080
      advertise:        tls:${ZITI_EDGE_ROUTER_HOSTNAME}:10080
      options:
        outQueueSize:   16
  dialers:
    - binding: transport

listeners:
  - binding: tunnel
    options:
      mode: host #tproxy|tun|host
  - binding: edge
    address: tls:0.0.0.0:${ZITI_EDGE_ROUTER_PORT}
    options:
      advertise: ${ZITI_EDGE_ROUTER_HOSTNAME}:${ZITI_EDGE_ROUTER_PORT}
      connectTimeoutMs: 5000
      getSessionTimeout: 60s

edge:
  csr:
    country: US
    province: NC
    locality: Charlotte
    organization: NetFoundry
    organizationalUnit: Ziti
    sans:
      dns:
        - ${ZITI_EDGE_ROUTER_HOSTNAME}
        - localhost
      ip:
        - "127.0.0.1"

#transport:
#  ws:
#    writeTimeout:      10
#    readTimeout:       5
#    idleTimeout:       5
#    pongTimeout:       60
#    pingInterval:      54
#    handshakeTimeout:  10
#    readBufferSize:    4096
#    writeBufferSize:   4096
#    enableCompression: true
#    server_cert:       ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_WSS_ROUTER_HOSTNAME-}-router-server.cert
#    key:               ${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_EDGE_WSS_ROUTER_HOSTNAME-}-router-server.key

forwarder:
  latencyProbeInterval: 1000
  xgressDialQueueLength: 1000
  xgressDialWorkerCount: 128
  linkDialQueueLength: 1000
  linkDialWorkerCount: 10
HereDocForEdgeRouter

echo -e "edge router configuration file written to: $(BLUE "${output_file}")"
}

function createFabricIdentity {
  output_file="${ZITI_HOME}/identities.yaml"
cat > "${output_file}" <<IdentitiesJsonHereDoc
---
default:
  caCert:   "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_CONTROLLER_HOSTNAME}-server.chain.pem"
  cert:     "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_NETWORK-}-dotzeet.cert"
  key:      "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_NETWORK-}-dotzeet.key"
  endpoint: tls:${ZITI_CONTROLLER_HOSTNAME}:${ZITI_FAB_MGMT_PORT}
IdentitiesJsonHereDoc

echo -e "identities file written to: $(BLUE "${output_file}")"
}

# shellcheck disable=SC2120
function createControllerConfig {
  # Allow controller name to be passed in as arg
  controller_name="${1-}"
  # If no controller name provided and env var is not set, prompt user for a controller name
  if [[ "${controller_name}" == "" ]] && [[ -z "${ZITI_EDGE_CONTROLLER_RAWNAME}" ]]; then
        echo -e "$(YELLOW "createControllerConfig requires a controller name to be supplied") "
        echo -en "Enter controller name: "
        read -r controller_name

        # Quit if no name is provided
        if [[ "${controller_name}" == "" ]]; then
          echo -e "$(RED "  --- Invalid controller name provided ---")"
          return 1
        fi
  # If no controller name provided and env var is set, use env var
  elif [[ "${controller_name}" == "" ]] && [[ -n "${ZITI_EDGE_CONTROLLER_RAWNAME}" ]]; then
    controller_name="${ZITI_EDGE_CONTROLLER_RAWNAME}"
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

cat "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_CONTROLLER_HOSTNAME}-server.chain.pem" > "${ZITI_PKI_OS_SPECIFIC}/cas.pem"
cat "${ZITI_PKI_OS_SPECIFIC}/${ZITI_SIGNING_INTERMEDIATE_NAME}/certs/${ZITI_SIGNING_INTERMEDIATE_NAME}.cert" >> "${ZITI_PKI_OS_SPECIFIC}/cas.pem"
echo -e "wrote CA file to: $(BLUE "${ZITI_PKI_OS_SPECIFIC}/cas.pem")"

output_file="${ZITI_HOME}/${controller_name}.yaml"
cat > "${output_file}" <<HereDocForEdgeConfiguration
v: 3

#trace:
#  path: "${ZITI_CONTROLLER_RAWNAME}.trace"

#profile:
#  memory:
#    path: ctrl.memprof

db:                     "${ZITI_HOME_OS_SPECIFIC}/db/ctrl.db"

identity:
  cert:                 "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_CONTROLLER_HOSTNAME}-client.cert"
  server_cert:          "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_CONTROLLER_HOSTNAME}-server.chain.pem"
  key:                  "${ZITI_PKI_OS_SPECIFIC}/${ZITI_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_CONTROLLER_HOSTNAME}-server.key"
  ca:                   "${ZITI_PKI_OS_SPECIFIC}/cas.pem"

ctrl:
  listener:             tls:0.0.0.0:${ZITI_FAB_CTRL_PORT}

mgmt:
  listener:             tls:${ZITI_CONTROLLER_HOSTNAME}:${ZITI_FAB_MGMT_PORT}

#metrics:
#  influxdb:
#    url:                http://localhost:8086
#    database:           ziti

# xctrl_example
#
#example:
#  enabled:              false
#  delay:                5s

# By having an 'edge' section defined, the ziti-controller will attempt to parse the edge configuration. Removing this
# section, commenting out, or altering the name of the section will cause the edge to not run.
edge:
  # This section represents the configuration of the Edge API that is served over HTTPS
  api:
    #(optional, default 90s) Alters how frequently heartbeat and last activity values are persisted
    # activityUpdateInterval: 90s
    #(optional, default 250) The number of API Sessions updated for last activity per transaction
    # activityUpdateBatchSize: 250
    # sessionTimeout - optional, default 10m
    # The number of minutes before an Edge API session will timeout. Timeouts are reset by
    # API requests and connections that are maintained to Edge Routers
    sessionTimeout: 30m
    # address - required
    # The default address (host:port) to use for enrollment for the Client API. This value must match one of the addresses
    # defined in this webListener's bindPoints.
    address: ${ZITI_EDGE_CONTROLLER_API}
  # This section is used to define option that are used during enrollment of Edge Routers, Ziti Edge Identities.
  enrollment:
    # signingCert - required
    # A Ziti Identity configuration section that specifically makes use of the cert and key fields to define
    # a signing certificate from the PKI that the Ziti environment is using to sign certificates. The signingCert.cert
    # will be added to the /.well-known CA store that is used to bootstrap trust with the Ziti Controller.
    signingCert:
      cert: ${ZITI_PKI_OS_SPECIFIC}/${ZITI_SIGNING_INTERMEDIATE_NAME}/certs/${ZITI_SIGNING_INTERMEDIATE_NAME}.cert
      key:  ${ZITI_PKI_OS_SPECIFIC}/${ZITI_SIGNING_INTERMEDIATE_NAME}/keys/${ZITI_SIGNING_INTERMEDIATE_NAME}.key
    # edgeIdentity - optional
    # A section for identity enrollment specific settings
    edgeIdentity:
      # durationMinutes - optional, default 5m
      # The length of time that a Ziti Edge Identity enrollment should remain valid. After
      # this duration, the enrollment will expire and not longer be usable.
      duration: 14400m
    # edgeRouter - Optional
    # A section for edge router enrollment specific settings.
    edgeRouter:
      # durationMinutes - optional, default 5m
      # The length of time that a Ziti Edge Router enrollment should remain valid. After
      # this duration, the enrollment will expire and not longer be usable.
      duration: 14400m

# web
# Defines webListeners that will be hosted by the controller. Each webListener can host many APIs and be bound to many
# bind points.
web:
  # name - required
  # Provides a name for this listener, used for logging output. Not required to be unique, but is highly suggested.
  - name: client-management
    # bindPoints - required
    # One or more bind points are required. A bind point specifies an interface (interface:port string) that defines
    # where on the host machine the webListener will listen and the address (host:port) that should be used to
    # publicly address the webListener(i.e. mydomain.com, localhost, 127.0.0.1). This public address may be used for
    # incoming address resolution as well as used in responses in the API.
    bindPoints:
      #interface - required
      # A host:port string on which network interface to listen on. 0.0.0.0 will listen on all interfaces
      - interface: 0.0.0.0:${ZITI_EDGE_CONTROLLER_PORT}
        # address - required
        # The public address that external incoming requests will be able to resolve. Used in request processing and
        # response content that requires full host:port/path addresses.
        address: ${ZITI_EDGE_CONTROLLER_API}
    # identity - optional
    # Allows the webListener to have a specific identity instead of defaulting to the root 'identity' section.
    identity:
      ca:          "${ZITI_PKI_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}.cert"
      key:         "${ZITI_PKI_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}/keys/${ZITI_EDGE_CONTROLLER_HOSTNAME}-server.key"
      server_cert: "${ZITI_PKI_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_CONTROLLER_HOSTNAME}-server.chain.pem"
      cert:        "${ZITI_PKI_OS_SPECIFIC}/${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}/certs/${ZITI_EDGE_CONTROLLER_HOSTNAME}-client.cert"
    # options - optional
    # Allows the specification of webListener level options - mainly dealing with HTTP/TLS settings. These options are
    # used for all http servers started by the current webListener.
    options:
      # idleTimeoutMs - optional, default 5000ms
      # The maximum amount of idle time in milliseconds allowed for pipelined HTTP requests. Setting this too high
      # can cause resources on the host to be consumed as clients remain connected and idle. Lowering this value
      # will cause clients to reconnect on subsequent HTTPs requests.
      idleTimeout: 5000ms  #http timeouts, new
      # readTimeoutMs - optional, default 5000ms
      # The maximum amount of time in milliseconds http servers will wait to read the first incoming requests. A higher
      # value risks consuming resources on the host with clients that are acting bad faith or suffering from high latency
      # or packet loss. A lower value can risk losing connections to high latency/packet loss clients.
      readTimeout: 5000ms
      # writeTimeoutMs - optional, default 10000ms
      # The total maximum time in milliseconds that the http server will wait for a single requests to be received and
      # responded too. A higher value can allow long running requests to consume resources on the host. A lower value
      # can risk ending requests before the server has a chance to respond.
      writeTimeout: 100000ms
      # minTLSVersion - optional, default TSL1.2
      # The minimum version of TSL to support
      minTLSVersion: TLS1.2
      # maxTLSVersion - optional, default TSL1.3
      # The maximum version of TSL to support
      maxTLSVersion: TLS1.3
    # apis - required
    # Allows one or more APIs to be bound to this webListener
    apis:
      # binding - required
      # Specifies an API to bind to this webListener. Built-in APIs are
      #   - edge-management
      #   - edge-client
      #   - fabric-management
      - binding: edge-management
        # options - arg optional/required
        # This section is used to define values that are specified by the API they are associated with.
        # These settings are per API. The example below is for the 'edge-api' and contains both optional values and
        # required values.
        options: { }
      - binding: edge-client
        options: { }

HereDocForEdgeConfiguration

  echo -e "Controller configuration file written to: $(BLUE "${output_file}")"
}

# shellcheck disable=SC2120
function ziti_createEnvFile {
  checkEnvVariable ZITI_HOME
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    if decideToUseDefaultZitiHome; then
      # shellcheck disable=SC2155
      export ZITI_NETWORK="$(hostname)"
      ZITI_HOME="${DEFAULT_ZITI_HOME_LOCATION}"
    else
      return 1
    fi
  fi

  export ZITI_HOME="${ZITI_HOME}"
  if [[ "${ZITI_OSTYPE}" == "windows" ]]; then
    export ZITI_HOME_OS_SPECIFIC="$(cygpath -m "${ZITI_HOME}")"
  else
    export ZITI_HOME_OS_SPECIFIC="${ZITI_HOME}"
  fi
  export ENV_FILE="${ZITI_HOME}/${ZITI_NETWORK}.env"
  export ZITI_SHARED="${ZITI_HOME}"

  checkEnvVariable ENV_FILE
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

  if [[ "${network_name-}" != "" ]]; then
    export ZITI_NETWORK="${network_name}"
  fi

  if [[ "${ZITI_NETWORK-}" == "" ]]; then
    if [[ "${1-}" != "" ]]; then
      export ZITI_NETWORK="${1-}"
    fi
    if [[ "${ZITI_NETWORK-}" = "" ]]; then
      echo -e "$(YELLOW "WARN: ZITI_NETWORK HAS NOT BEEN DECLARED! USING hostname: $(hostname)")"
      # shellcheck disable=SC2155
      export ZITI_NETWORK="$(hostname)"
    fi
  fi

  echo "ZITI_NETWORK set to: ${ZITI_NETWORK}"

  if [[ "${ZITI_USER-}" == "" ]]; then export ZITI_USER="admin"; fi
  if [[ "${ZITI_PWD-}" == "" ]]; then export ZITI_PWD="admin"; fi
  if [[ "${ZITI_DOMAIN_SUFFIX-}" == "" ]]; then export ZITI_DOMAIN_SUFFIX=""; fi
  if [[ "${ZITI_ID-}" == "" ]]; then export ZITI_ID="${ZITI_HOME}/identities.yaml"; fi
  if [[ "${ZITI_FAB_MGMT_PORT-}" == "" ]]; then export ZITI_FAB_MGMT_PORT="10000"; fi
  if [[ "${ZITI_FAB_CTRL_PORT-}" == "" ]]; then export ZITI_FAB_CTRL_PORT="6262"; fi

  if [[ "${ZITI_CONTROLLER_RAWNAME-}" == "" ]]; then export ZITI_CONTROLLER_RAWNAME="${ZITI_NETWORK}-controller"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_RAWNAME-}" == "" ]]; then export ZITI_EDGE_CONTROLLER_RAWNAME="${ZITI_NETWORK}-edge-controller"; fi

  export ZITI_PKI="${ZITI_SHARED}/pki"
  if [[ "${ZITI_OSTYPE}" == "windows" ]]; then
    export ZITI_PKI_OS_SPECIFIC="$(cygpath -m "${ZITI_PKI}")"
  else
    export ZITI_PKI_OS_SPECIFIC="${ZITI_PKI}"
  fi
  if [[ "${ZITI_EDGE_CONTROLLER_PORT-}" == "" ]]; then export ZITI_EDGE_CONTROLLER_PORT="1280"; fi

  if [[ "${ZITI_CONTROLLER_HOSTNAME-}" == "" ]]; then export ZITI_CONTROLLER_HOSTNAME="${ZITI_CONTROLLER_RAWNAME}${ZITI_DOMAIN_SUFFIX}"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_HOSTNAME-}" == "" ]]; then export ZITI_EDGE_CONTROLLER_HOSTNAME="${ZITI_EDGE_CONTROLLER_RAWNAME}${ZITI_DOMAIN_SUFFIX}"; fi
  if [[ "${ZITI_ZAC_HOSTNAME-}" == "" ]]; then export ZITI_ZAC_HOSTNAME="${ZITI_ZAC_RAWNAME}${ZITI_DOMAIN_SUFFIX}"; fi
  if [[ "${ZITI_EDGE_CONTROLLER_API-}" == "" ]]; then export ZITI_EDGE_CONTROLLER_API="${ZITI_EDGE_CONTROLLER_HOSTNAME}:${ZITI_EDGE_CONTROLLER_PORT}"; fi

  export ZITI_SIGNING_CERT_NAME="${ZITI_NETWORK}-signing"

  export ZITI_CONTROLLER_ROOTCA_NAME="${ZITI_CONTROLLER_HOSTNAME}-root-ca"
  export ZITI_CONTROLLER_INTERMEDIATE_NAME="${ZITI_CONTROLLER_HOSTNAME}-intermediate"

  export ZITI_EDGE_CONTROLLER_ROOTCA_NAME="${ZITI_EDGE_CONTROLLER_HOSTNAME}-root-ca"
  export ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME="${ZITI_EDGE_CONTROLLER_HOSTNAME}-intermediate"

  export ZITI_SIGNING_ROOTCA_NAME="${ZITI_SIGNING_CERT_NAME}-root-ca"
  export ZITI_SIGNING_INTERMEDIATE_NAME="${ZITI_SIGNING_CERT_NAME}-intermediate"

  export ZITI_BIN_ROOT="${ZITI_HOME}/ziti-bin"

  mkdir -p "${ZITI_BIN_ROOT}"
  mkdir -p "${ZITI_HOME}/db"
  mkdir -p "${ZITI_PKI}"

  echo "" > "${ENV_FILE}"
  for zEnvVar in $(set | grep -e "^ZITI_" | sort); do envvar="$(echo "${zEnvVar}" | cut -d '=' -f1)"; envval="$(echo "${zEnvVar}" | cut -d '=' -f2-100)"; echo "export ${envvar}=\"${envval}\"" >> "${ENV_FILE}"; done

  export PFXLOG_NO_JSON=true
  # shellcheck disable=SC2129
  echo "export PFXLOG_NO_JSON=true" >> "${ENV_FILE}"

  echo "alias zec='ziti edge'" >> "${ENV_FILE}"
  echo "alias zlogin='ziti edge login \"\${ZITI_EDGE_CONTROLLER_API}\" -u \"\${ZITI_USER-}\" -p \"\${ZITI_PWD}\" -c \"\${ZITI_PKI}/\${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}/certs/\${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}.cert\"'" >> "${ENV_FILE}"
  echo "alias zitiLogin='ziti edge login \"\${ZITI_EDGE_CONTROLLER_API}\" -u \"\${ZITI_USER-}\" -p \"\${ZITI_PWD}\" -c \"\${ZITI_PKI}/\${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}/certs/\${ZITI_EDGE_CONTROLLER_INTERMEDIATE_NAME}.cert\"'" >> "${ENV_FILE}"
  echo "alias psz='ps -ef | grep ziti'" >> "${ENV_FILE}"

  #when sourcing the emitted file add the bin folder to the path
  tee -a "${ENV_FILE}" > /dev/null <<'heredoc'
echo " "
if [[ ! "$(echo "$PATH"|grep -q "${ZITI_BIN_DIR}" && echo "yes")" == "yes" ]]; then
  echo "adding ${ZITI_BIN_DIR} to the path"
  export PATH=$PATH:"${ZITI_BIN_DIR}"
else
echo    "                  ziti binaries are located at: ${ZITI_BIN_DIR}"
echo -e 'add this to your path if you want by executing: export PATH=$PATH:'"${ZITI_BIN_DIR}"
echo " "
fi
heredoc

echo -e "env file written to: $(BLUE "${ENV_FILE}")"
}

function waitForController {
  #devnull="/dev/null"
  #if [[ "${ZITI_OSTYPE}" == "windows" ]]; then
  #  devnull="nul"
  #fi
  # shellcheck disable=SC2091
  #until $(curl -o /dev/null -sk /dev/null --fail "https://${ZITI_EDGE_CONTROLLER_API}"); do
  #    echo "waiting for https://${ZITI_EDGE_CONTROLLER_API}"
  #    sleep 2
  #done
  while [[ "$(curl -w "%{http_code}" -m 1 -s -k -o /dev/null https://${ZITI_EDGE_CONTROLLER_API}/version)" != "200" ]]; do
    echo "waiting for https://${ZITI_EDGE_CONTROLLER_API}"
    sleep 3
  done
}

function createControllerSystemdFile {
  # Allow controller name to be passed in as arg
  controller_name="${1-}"
  # If no controller name provided and env var is not set, prompt user for a controller name
  if [[ "${controller_name}" == "" ]] && [[ -z "${ZITI_EDGE_CONTROLLER_RAWNAME}" ]]; then
        echo -e "$(YELLOW "createControllerSystemdFile requires a controller name to be supplied") "
        echo -en "Enter controller name:"
        read -r controller_name

        # Quit if no name is provided
        if [[ "${controller_name}" == "" ]]; then
          echo -e "$(RED "  --- Invalid controller name provided ---")"
          return 1
        fi
  # If no controller name provided and env var is set, use env var
  elif [[ "${controller_name}" == "" ]] && [[ -n "${ZITI_EDGE_CONTROLLER_RAWNAME}" ]]; then
    controller_name="${ZITI_EDGE_CONTROLLER_RAWNAME}"
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME}/${controller_name}.service"
cat > "${output_file}" <<HeredocForSystemd
[Unit]
Description=Ziti-Controller
After=network.target

[Service]
User=root
WorkingDirectory=${ZITI_HOME}
ExecStart="${ZITI_BIN_DIR}/ziti-controller" run "${ZITI_HOME}/${controller_name}.yaml"
Restart=always
RestartSec=2
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target

HeredocForSystemd
  echo -e "Controller systemd file written to: $(BLUE "${output_file}")"
}

function createRouterSystemdFile {
  # Allow router name to be passed in as arg
  router_name="${1-}"
  if [[ "${router_name}" == "" ]]; then

    # If router name is not passed as arg, prompt user for input
    echo -e "$(YELLOW "createRouterSystemdFile requires a router name to be supplied") "
    default_router_name="${ZITI_EDGE_ROUTER_RAWNAME}"
    echo -en "Enter router name (${default_router_name}):"
    read -r router_name

    # Accept the default if no name provided
    if [[ "${router_name}" == "" ]]; then
      # Check for overwrite of default file
      router_name="${default_router_name}"
      getFileOverwritePermission "${ZITI_HOME-}/${router_name}.service"
      retVal=$?
      if [[ "${retVal}" != 0 ]]; then
        return 1
      fi
    fi
  fi

  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME}/${router_name}.service"
cat > "${output_file}" <<HeredocForSystemd
[Unit]
Description=Ziti-Router for ${router_name}
After=network.target

[Service]
User=root
WorkingDirectory=${ZITI_HOME}
ExecStart="${ZITI_BIN_DIR}/ziti-router" run "${ZITI_HOME}/${router_name}.yaml"
Restart=always
RestartSec=2
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

HeredocForSystemd
  echo -e "Router systemd file written to: $(BLUE "${output_file}")"
}

function createControllerLaunchdFile {
  # Allow controller name to be passed in as arg
  controller_name="${1-}"
  # If no controller name provided and env var is not set, prompt user for a controller name
  if [[ "${controller_name}" == "" ]] && [[ -z "${ZITI_EDGE_CONTROLLER_RAWNAME}" ]]; then
        echo -e "$(YELLOW "createControllerLaunchdFile requires a controller name to be supplied") "
        echo -en "Enter controller name: "
        read -r controller_name

        # Quit if no name is provided
        if [[ "${controller_name}" == "" ]]; then
          echo -e "$(RED "  --- Invalid controller name provided ---")"
          return 1
        fi
  # If no controller name provided and env var is set, use env var
  elif [[ "${controller_name}" == "" ]] && [[ -n "${ZITI_EDGE_CONTROLLER_RAWNAME}" ]]; then
    controller_name="${ZITI_EDGE_CONTROLLER_RAWNAME}"
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME}/${controller_name}.plist"
cat > "${output_file}" <<HeredocForLaunchd
<?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>ziti-controller-${controller_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>$ZITI_BIN_DIR/ziti-controller</string>
        <string>run</string>
        <string>$ZITI_HOME/${controller_name}.yaml</string>
      </array>
      <key>WorkingDirectory</key>
      <string>${ZITI_HOME}</string>
      <key>KeepAlive</key>
      <dict>
        <key>PathState</key>
        <dict>
          <key>${ZITI_HOME}/launchd-enabled</key>
          <true/>
        </dict>
      </dict>
      <key>StandardOutPath</key>
      <string>${ZITI_HOME}/Logs/${controller_name}-{ZITI_BINARIES_VERSION}.log</string>
      <key>StandardErrorPath</key>
      <string>${ZITI_HOME}/Logs/${controller_name}-{ZITI_BINARIES_VERSION}.log</string>
    </dict>
  </plist>
HeredocForLaunchd
  echo -e "Controller launchd file written to: $(BLUE "${output_file}")"

  showLaunchdMessage
}

function createRouterLaunchdFile {
  # Allow router name to be passed in as arg
  router_name="${1-}"
  if [[ "${router_name}" == "" ]]; then

    # If router name is not passed as arg, prompt user for input
    echo -e "$(YELLOW "createRouterLaunchdFile requires a router name to be supplied") "
    default_router_name="${ZITI_EDGE_ROUTER_RAWNAME}"
    echo -en "Enter router name (${default_router_name}):"
    read -r router_name

    # Accept the default if no name provided
    if [[ "${router_name}" == "" ]]; then
      # Check for overwrite of default file
      router_name="${default_router_name}"
      getFileOverwritePermission "${ZITI_HOME-}/${router_name}.plist"
      retVal=$?
      if [[ "${retVal}" != 0 ]]; then
        return 1
      fi
    fi
  fi

  # Make sure necessary env variables are set
  checkEnvVariable ZITI_HOME ZITI_BIN_DIR
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME-}/${router_name}.plist"
cat > "${output_file}" <<HeredocForLaunchd
<?xml version="1.0" encoding="UTF-8"?>
  <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
  <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>$router_name</string>
      <key>ProgramArguments</key>
      <array>
        <string>$ZITI_BIN_DIR/ziti-router</string>
        <string>run</string>
        <string>$ZITI_HOME/ctrl.with.edge.yml</string>
      </array>
      <key>WorkingDirectory</key>
      <string>${ZITI_HOME}</string>
      <key>KeepAlive</key>
      <true/>
      <dict>
        <key>PathState</key>
        <dict>
          <key>${ZITI_HOME}/launchd-enabled</key>
          <true/>
        </dict>
      </dict>
      <key>StandardOutPath</key>
      <string>${ZITI_HOME}/Logs/${router_name}-${ZITI_BINARIES_VERSION}.log</string>
      <key>StandardErrorPath</key>
      <string>${ZITI_HOME}/Logs/${router_name}-${ZITI_BINARIES_VERSION}.log</string>
    </dict>
  </plist>
HeredocForLaunchd
  echo -e "Router launchd file written to: $(BLUE "${output_file}")"

  showLaunchdMessage
}

function showLaunchdMessage {
  echo -e " "
  echo -e "$(YELLOW "The generated launchd file is designed to keep the service alive while the file")"
  echo -e "$(BLUE "${ZITI_HOME}/launchd-enabled") $(YELLOW "remains present.")"
  echo -e "$(YELLOW "If this file is not present, the service will end.")"
}

function createZacSystemdFile {

  checkEnvVariable ZITI_HOME
  retVal=$?
  if [[ "${retVal}" != 0 ]]; then
    return 1
  fi

output_file="${ZITI_HOME}/ziti-console.service"
cat > "${output_file}" <<HeredocForSystemd
[Unit]
Description=Ziti-Console
After=network.target

[Service]
User=root
WorkingDirectory=${ZITI_HOME}/ziti-console
ExecStart=node "${ZITI_HOME}/ziti-console/server.js"
Restart=always
RestartSec=2
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target

HeredocForSystemd
  echo -e "ziti-console systemd file written to: $(BLUE "${output_file}")"
}

function setOs {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
          export ZITI_OSTYPE="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
          export ZITI_OSTYPE="darwin"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
          export ZITI_OSTYPE="windows"
          #echo -e "  * ERROR: $(RED "\$OSTYPE [$OSTYPE] is not supported at this time") "
          #return 1
  elif [[ "$OSTYPE" == "msys" ]]; then
          export ZITI_OSTYPE="windows"
          #echo -e "  * ERROR: $(RED "\$OSTYPE [$OSTYPE] is not supported at this time") "
          #return 1
  elif [[ "$OSTYPE" == "win32" ]]; then
          export ZITI_OSTYPE="windows"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
          echo -e "  * ERROR: $(RED "\$OSTYPE [$OSTYPE] is not supported at this time") "
          return 1
  else
          echo -e "  * ERROR: $(RED "\$OSTYPE is not set or is unknown: [$OSTYPE]. Cannot continue") "
          return 1
  fi
  return 0
}

function checkEnvVariable() {

  for arg
  do
    # Parameter expansion is different between shells
    if [[ -n "$ZSH_VERSION" ]]; then
      if [[ -z "${(P)arg}" ]]; then
        echo -e "  * ERROR: $(RED "${arg} is not set") "
        return 1
      fi
    elif [[ -n "$BASH_VERSION" ]]; then
      if [[ -z "${!arg}" ]]; then
        echo -e "  * ERROR: $(RED "${arg} is not set") "
        return 1
      fi
    else
      echo -e " * $(RED "Unsupported shell, supply a PR or log an issue on https://github.com/openziti/ziti") "
      return 1
    fi
  done
  return 0
}

function getFileOverwritePermission() {
  file_path="${1-}"

  if [[ -f "${file_path}" ]]; then
    echo -en "This will overwrite the existing file, continue (y/N)? "
    read -r
    if [[ "${REPLY}" == [^Yy]* ]]; then
      echo -e "$(RED "  --- Cancelling overwrite ---")"
      return 1
    fi

    return 0
  fi
}

set +uo pipefail

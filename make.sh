#!/bin/bash
#
# NAME
#
#   make.sh
#
# SYNPOSIS
#
#   make.sh                     [-i] [-s] [-U]                  \
#                               [-S <storeBaseOverride>]        \
#                               [local|fnndsc[:dev]]
#
# DESC
#
#   'make.sh' sets up a pfcon development instance using docker stack deploy.
#   It can also optionally create a pattern of directories and symbolic links
#   that reflect the declarative environment of the docker-compose_dev.yml contents.
#
# TYPICAL CASES:
#
#   Run full pfcon instantiation:
#
#       unmake.sh ; sudo rm -fr FS; rm -fr FS; make.sh
#
#   Skip the intro:
#
#       unmake.sh ; sudo rm -fr FS; rm -fr FS; make.sh -s
#
# ARGS
#
#
#   -S <storeBaseOverride>
#
#       Explicitly set the STOREBASE dir to <storeBaseOverride>. This is useful
#       mostly in non-Linux hosts (like macOS) where there might be a mismatch
#       between the actual STOREBASE path and the text of the path shared between
#       the macOS host and the docker VM.
#
#   -i
#
#       Optional do not automatically attach interactive terminal to pfcon container.
#
#   -U
#
#       Optional skip the UNIT tests.
#
#   -s
#
#       Optional skip intro steps. This skips the check on latest versions
#       of containers and the interval version number printing. Makes for
#       slightly faster startup.
#
#   [local|fnndsc[:dev]] (optional, default = 'fnndsc')
#
#       If specified, denotes the container "family" to use.
#
#       If a colon suffix exists, then this is interpreted to further
#       specify the TAG, i.e :dev in the example above.
#
#       The 'fnndsc' family are the containers as hosted on docker hub.
#       Using 'fnndsc' will always attempt to pull the latest container first.
#
#       The 'local' family are containers that are assumed built on the local
#       machine and assumed to exist. The 'local' containers are used when
#       the 'pfcon/pman' services are being locally developed/debugged.
#
#

source ./decorate.sh
source ./cparse.sh

declare -i STEP=0
HERE=$(pwd)
echo "Starting script in dir $HERE"

export PFCONREPO=fnndsc
export PMANREPO=fnndsc
export TAG=

while getopts "siUa:S:" opt; do
    case $opt in
        s) b_skipIntro=1                        ;;
        i) b_norestartinteractive_pfcon_dev=1   ;;
        U) b_skipUnitTests=1                    ;;
        S) b_storeBaseOverride=1
           STOREBASE=$OPTARG                    ;;
    esac
done

shift $(($OPTIND - 1))
if (( $# == 1 )) ; then
    REPO=$1
    export PFCONREPO=$(echo $REPO | awk -F \: '{print $1}')
    export TAG=$(echo $REPO | awk -F \: '{print $2}')
    if (( ${#TAG} )) ; then
        TAG=":$TAG"
    fi
fi

declare -a A_CONTAINER=(
    "fnndsc/pfcon:dev^PFCONREPO"
    "fnndsc/pman^PMANREPO"
    "fnndsc/pl-simplefsapp"
)

title -d 1 "Setting global exports..."
    if (( ! b_storeBaseOverride )) ; then
        if [[ ! -d FS/remote ]] ; then
            mkdir -p FS/remote
        fi
        cd FS/remote
        STOREBASE=$(pwd)
        cd $HERE
    fi
    echo -e "${STEP}.1 For pman override to swarm containers,"          | ./boxes.sh
    echo -e "exporting STOREBASE=$STOREBASE "                           | ./boxes.sh
    export STOREBASE=$STOREBASE
windowBottom

if (( ! b_skipIntro )) ; then
    title -d 1 "Pulling non-'local/' core containers where needed..."
    for CORE in ${A_CONTAINER[@]} ; do
        cparse $CORE " " "REPO" "CONTAINER" "MMN" "ENV"
        if [[ $REPO != "local" ]] ; then
            echo ""                                                 | ./boxes.sh
            CMD="docker pull ${REPO}/$CONTAINER"
            printf "${LightCyan}%-40s${Green}%40s${Yellow}\n"       \
                        "docker pull" "${REPO}/$CONTAINER"          | ./boxes.sh
            windowBottom
            sleep 1
            echo $CMD | sh                                          | ./boxes.sh -c
        fi
    done
fi
windowBottom

if (( ! b_skipIntro )) ; then
    title -d 1 "Will use containers with following version info:"
    for CORE in ${A_CONTAINER[@]} ; do
        cparse $CORE " " "REPO" "CONTAINER" "MMN" "ENV"
        if [[   $CONTAINER != "pl-simplefsapp"  ]] ; then
            windowBottom
            CMD="docker run --entrypoint $CONTAINER ${REPO}/$CONTAINER --version"
            if [[   $CONTAINER == "pfcon:dev"  ]] ; then
              CMD="docker run --entrypoint pfcon ${REPO}/$CONTAINER --version"
            fi
            Ver=$(echo $CMD | sh | grep Version)
            echo -en "\033[2A\033[2K"
            printf "${White}%40s${Green}%40s${Yellow}\n"            \
                    "${REPO}/$CONTAINER" "$Ver"                     | ./boxes.sh
        fi
    done
fi

title -d 1 "Shutting down any running pfcon and related containers... "
    echo "This might take a few minutes... please be patient."              | ./boxes.sh ${Yellow}
    windowBottom
    docker stack rm pfcon_dev_stack >& dc.out > /dev/null
    echo -en "\033[2A\033[2K"
    cat dc.out | sed -E 's/(.{80})/\1\n/g'                                  | ./boxes.sh ${LightBlue}
    for CORE in ${A_CONTAINER[@]} ; do
        cparse $CORE " " "REPO" "CONTAINER" "MMN" "ENV"
        docker ps -a                                                        |\
            grep $CONTAINER                                                 |\
            awk '{printf("docker stop %s && docker rm -vf %s\n", $1, $1);}' |\
            sh >/dev/null                                                   | ./boxes.sh
        printf "${White}%40s${Green}%40s${NC}\n"                            \
                    "$CONTAINER" "stopped"                                  | ./boxes.sh
    done
windowBottom

title -d 1 "Changing permissions to 755 on" "$(pwd)"
    cd $HERE
    echo "chmod -R 755 $(pwd)"                                      | ./boxes.sh
    chmod -R 755 $(pwd)
windowBottom

title -d 1 "Checking that FS directory tree is empty..."
    mkdir -p FS/remote
    chmod -R 777 FS
    b_FSOK=1
    type -all tree >/dev/null 2>/dev/null
    if (( ! $? )) ; then
        tree FS                                                     | ./boxes.sh
        report=$(tree FS | tail -n 1)
        if [[ "$report" != "1 directory, 0 files" ]] ; then
            b_FSOK=0
        fi
    else
        report=$(find FS 2>/dev/null)
        lines=$(echo "$report" | wc -l)
        if (( lines != 2 )) ; then
            b_FSOK=0
        fi
        echo "lines is $lines"
    fi
    if (( ! b_FSOK )) ; then
        printf "There should only be 1 directory and no files in the FS tree!\n"    | ./boxes.sh ${Red}
        printf "Please manually clean/delete the entire FS tree and re-run.\n"      | ./boxes.sh ${Yellow}
        printf "\nThis script will now exit with code '1'.\n\n"                     | ./boxes.sh ${Yellow}
        exit 1
    fi
    printf "${LightCyan}%40s${LightGreen}%40s\n"                    \
                "Tree state" "[ OK ]"                               | ./boxes.sh
windowBottom

title -d 1 "Starting pfcon_dev_stack containerized dev environment on Swarm"
    echo "docker stack deploy -c docker-compose_dev.yml pfcon_dev_stack" | ./boxes.sh ${LightCyan}
    windowBottom
    docker stack deploy -c docker-compose_dev.yml pfcon_dev_stack >& dc.out > /dev/null
    echo -en "\033[2A\033[2K"
    cat dc.out | sed -E 's/(.{80})/\1\n/g'                          | ./boxes.sh ${LightGreen}
windowBottom

title -d 1 "Waiting until containers for pfcon_dev_stack are running on Swarm"
    echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
    windowBottom
    for i in {1..20}; do
      sleep 5
      pfcon_dev=$(docker ps -f name=pfcon_dev_stack_pfcon_service.1 -q)
      if [ -n "$pfcon_dev" ]; then
        echo "Success: pfcon_dev_stack's containers are up"      | ./boxes.sh ${Green}
        break
      fi
    done
    if [ -z "$pfcon_dev" ]; then
        echo "Error: couldn't start pfcon_dev_stack's containers"      | ./boxes.sh ${Red}
    fi
windowBottom

if (( ! b_skipUnitTests )) ; then
    title -d 1 "Running pfcon tests..."
    echo "This might take a few minutes... please be patient."      | ./boxes.sh ${Yellow}
    windowBottom
    docker exec $pfcon_dev nosetests --exe tests
    status=$?
    title -d 1 "pfcon test results"
    if (( $status == 0 )) ; then
        printf "%40s${LightGreen}%40s${NC}\n"                       \
            "pfcon tests" "[ success ]"                         | ./boxes.sh
    else
        printf "%40s${Red}%40s${NC}\n"                              \
            "pfcon tests" "[ failure ]"                         | ./boxes.sh
    fi
    windowBottom
fi

if (( !  b_norestartinteractive_pfcon_dev )) ; then
    title -d 1 "Attaching interactive terminal"                \
                        "(ctrl-a to detach)"
    docker logs $pfcon_dev
    docker attach --detach-keys ctrl-a $pfcon_dev
fi

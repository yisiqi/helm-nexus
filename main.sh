#!/bin/bash

usage() {
cat << EOF
Example Usage:
    Step 1 - Initial:
        helm repo add --username xxxx --password xxxx charts-private https://example.com/repository/charts
    Step 2 - Package:
        helm nexus package
        helm nexus package ./charts/
    Step 3 - Publish:
        helm nexus publish
        helm nexus publish charts-private
        helm nexus publish ./charts/ charts-private

Usage:
  helm nexus [flags] [command] ...

Available Commands:
    package     Package Helm chart packages
    publish     Publish Helm charts to your private repository

Global Flags:
    -h, --help              Print this help
    -v, --verbose           Enable verbose output
    -d, --dry-run           Simulate command running witout any effect result

Use "helm nexus [command] --help" for more information about a command.
EOF
}


if [[ -z "$NEXUS_API_VER" ]]; then
    CI_UPLOAD_API_VER=v1
else
    CI_UPLOAD_API_VER=$NEXUS_API_VER
fi

log_debug() {
    if [[ $DEBUG = TRUE ]]; then
        echo [DEBUG] $@
    fi
}

YQ=$HELM_PLUGIN_DIR/bin/yq.$(uname -s).$(uname -m)
LOCAL_REPO_NAMES=()
LOCAL_REPO_NAMES_LIST=$($YQ r $HELM_HOME/repository/repositories.yaml "repositories[*].name")
for LOCAL_REPO_NAME in ${LOCAL_REPO_NAMES_LIST[@]}; do
    if [[ ! X$LOCAL_REPO_NAME = "X-" ]]; then
        LOCAL_REPO_NAMES+=("$LOCAL_REPO_NAME")
    fi
done

check_repo() {
    for LOCAL_REPO_NAME in ${LOCAL_REPO_NAMES[@]}; do
        if [[ X$LOCAL_REPO_NAME = "X$1" ]]; then
            echo TRUE
            return
        fi
    done
}

get_repo_info() {
    for (( i=0; i<${#LOCAL_REPO_NAMES[@]}; i++ )); do
        # echo ITem ${LOCAL_REPO_NAMES[$i]} @$i
        if [[ ${LOCAL_REPO_NAMES[i]} = $1 ]]; then
            echo $($YQ r $HELM_HOME/repository/repositories.yaml "repositories[$i].$2")
            return
        fi
    done
}

do_upload() {
    CI_CURL_UPLOAD_URL=$1
    CI_CURL_UPLOAD_AUTH=$2
    CI_CURL_UPLOAD_FILE_PATH=$3
    CI_CURL_UPLOAD_FILE_NAME=$4

    if [[ ! -z "$DEBUG" ]]; then
        echo "curl -sSf -X POST $CI_CURL_UPLOAD_URL $2 \\"
        echo "   -F raw.directory=/ \\"
        echo "   -F raw.asset1=@$CI_CURL_UPLOAD_FILE_PATH \\"
        echo "   -F raw.asset1.filename=$CI_CURL_UPLOAD_FILE_NAME"
    fi

    if [[ -z "$DRY_RUN" ]]; then
        curl -sSf -X POST $CI_CURL_UPLOAD_URL $CI_CURL_UPLOAD_AUTH -F raw.directory=/ -F raw.asset1=@$CI_CURL_UPLOAD_FILE_PATH -F raw.asset1.filename=$CI_CURL_UPLOAD_FILE_NAME
    fi
}


# shift

# Create the passthru array
PASSTHRU=()
GLOBAL_FLAGS=()
while [[ $# -gt 0 ]]
do
key="$1"

# Parse arguments
case $key in
    --verbose|-v)
    log_debug Verbose mode is enabled.
    DEBUG=TRUE
    GLOBAL_FLAGS+=("$1")
    shift # past argument
    ;;
    --help|-h)
    HELP=TRUE
    GLOBAL_FLAGS+=("$1")
    shift # past argument
    ;;
    --dry-run|-d)
    DRY_RUN=TRUE
    GLOBAL_FLAGS+=("$1")
    shift # past argument
    ;;
    *)    # unknown option
    if [[ "$1" =~ ^-.* ]]; then
        echo Invalid command flag: \"$1\"
        exit 1
    else
        PASSTHRU+=("$1") # save it in an array for later
    fi
    shift # past argument
    ;;
esac
done

SUB_CMD=${PASSTHRU[0]}
if [[ X$SUB_CMD != "package" && X$SUB_CMD = "publish" ]]; then
    echo Error: Invalid command.
    echo
    usage
    exit
fi

# echo Sub-Command: $SUB_CMD
# echo DEBUG: $DEBUG

# $HELM_PLUGIN_DIR/$SUB_CMD.sh ${PASSTHRU[@]}
if [[ X$HELP = "XTRUE" || ${#PASSTHRU[@]} = 0 ]]; then
    echo Publish Helm charts to your private Sonatype Nexus Repository.
    echo
    usage
    exit
fi

if [[ X$SUB_CMD = "Xpackage" ]]; then
    if [[ X${PASSTHRU[1]} = "X" ]]; then
        CHARTS_DIR=./charts
    else
        CHARTS_DIR=$(dirname ${PASSTHRU[1]})/$(basename ${PASSTHRU[1]})
    fi

    rm -f ${CHARTS_DIR}/*.tgz
    helm package --destination ${CHARTS_DIR}/ ${CHARTS_DIR}/*/
fi

if [[ X$SUB_CMD = "Xpublish" ]]; then

    REPO_NAME=$($YQ r $HELM_HOME/repository/repositories.yaml "repositories[0].name")
    CHART_PKGS=()

    LAST_ARG=${PASSTHRU[${#PASSTHRU[@]} - 1]}
    IS_REPO_EXIST=$(check_repo $LAST_ARG)

    if [[ ${#PASSTHRU[@]} < 2 ]]; then
        # 未指定任何参数时
        log_debug Nothing specified, using default settings.
        CHART_PKGS=$(ls ./charts/*.tgz)
    elif [[ -f $LAST_ARG ]]; then
        # 至少有1个参数，且最后1个参数是文件路径
        log_debug The last arg is a vaild file. Will using the first repository to publish.
        CHART_PKGS=()
        for (( i=1; i<${#PASSTHRU[@]}; i++ )); do
            CHART_PKGS+=("${PASSTHRU[$i]}")
        done
    elif [[ X$IS_REPO_EXIST = "XTRUE" ]]; then
        # 至少有1个参数，且最后1个参数是仓库名
        log_debug The last arg is a name of existed repository.
        REPO_NAME=$LAST_ARG
        if [[ ${#PASSTHRU[@]} < 3 ]]; then
            log_debug Not specified any chart package file.
            for DEFAULT_CHART_PACK in $(ls ./charts/*.tgz); do
                CHART_PKGS+=("$DEFAULT_CHART_PACK")
            done
        else
            log_debug Go specified charts files.
            for (( i=1; i<${#PASSTHRU[@]} - 1; i++ )); do
                CHART_PKGS+=("${PASSTHRU[$i]}")
            done
        fi
    else
        echo Error: Plese recheck your arguments.
        echo
        usage
        exit 1
    fi

    echo
    echo Preparing to publish charts:
    for HN_PUB_EACH_CHART in ${CHART_PKGS[@]}; do
        echo "  - $HN_PUB_EACH_CHART"
    done
    echo "  (total: ${#CHART_PKGS[@]})"
    echo to repository: $REPO_NAME
    echo

    for CHART_PACK_FILE in ${CHART_PKGS[@]}; do
        if [[ -f $CHART_PACK_FILE && ${CHART_PACK_FILE: -4} == ".tgz" ]]; then
            # echo $CHART_PACK_FILE
            # echo $(dirname $CHART_PACK_FILE)
            CI_REPO_URL=$(get_repo_info $REPO_NAME url)
            CI_UPLOAD_URL=https://repos.iec.io/service/rest/$CI_UPLOAD_API_VER/components?repository=$(basename $CI_REPO_URL)
            CI_CHARTS_REPO_USERNAME=$(get_repo_info $REPO_NAME username)
            CI_CHARTS_REPO_PASSWORD=$(get_repo_info $REPO_NAME password)
            if [[ X$CI_CHARTS_REPO_USERNAME = "X" && X$CI_CHARTS_REPO_PASSWORD = "X" ]]; then
                CI_UPLOAD_AUTH=""
            else
                CI_UPLOAD_AUTH="-u $CI_CHARTS_REPO_USERNAME:$CI_CHARTS_REPO_PASSWORD"
            fi

            # Reindex
            rm -f $(dirname $CHART_PACK_FILE)/index.yaml || true
            helm repo index --merge ~/.helm/repository/cache/$REPO_NAME-index.yaml --url $CI_REPO_URL $(dirname $CHART_PACK_FILE)
            # Upload
            do_upload $CI_UPLOAD_URL "$CI_UPLOAD_AUTH" $CHART_PACK_FILE $(basename $CHART_PACK_FILE)
            do_upload $CI_UPLOAD_URL "$CI_UPLOAD_AUTH" $(dirname $CHART_PACK_FILE)/index.yaml index.yaml

            echo Publish success: $CHART_PACK_FILE "->" $REPO_NAME

        else
            echo
            echo Error: File \"$CHART_PACK_FILE\" is not a vaild chart package.
            echo
            exit 1
        fi
    done
fi

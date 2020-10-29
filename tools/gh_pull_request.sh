#!/usr/bin/env bash

function usage {
    echo "usage: gh_pull_request [-b base] [-h head] [-t token]"
    echo "  -r repo  specify the repo where to open the PR"
    echo "  -b base  specify the PR base"
    echo "  -h head  specify the PR head"
    echo "  -t token specify the oAuth token"
    return -1
}

function create_pr {
    commit_hash="$(git rev-parse --short HEAD)"
    http_code=$(curl --write-out "%{http_code}" \
         --silent --output /dev/null \
         -v -H "Authorization: token ${TOKEN}" \
         -d "{\"title\":\"data-model-proto-update\", \"base\":\"${BASE}\", \"head\":\"${HEAD}-${commit_hash}\"}" \
         https://api.github.com/repos/infarm/${REPO}/pulls)

    if [[ "${http_code}" == "201" ]]; then
        echo "Successfully created Pull Request"
        return 0
    elif [[ "${http_code}" == "422" ]]; then
        echo "No changes - no Pull Request needed"
        return 0
    else
        echo "Invalid response from GitHub API: "${http_code}
        return -2
    fi
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case ${key} in
    -r|--repo)
    REPO="$2"
    shift # past argument
    shift # past value
    ;;
    -b|--base)
    BASE="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--head)
    HEAD="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--token)
    TOKEN="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

set -e  # Exit immediately if a command exits with a non-zero status.
set -u  # Treat unset variables as an error when substituting.

if [[ -z "${REPO}" ]] || [[ -z "${BASE}" ]] || [[ -z "${HEAD}" ]] || [[ -z "${TOKEN}" ]]; then
    usage
else
    create_pr
fi

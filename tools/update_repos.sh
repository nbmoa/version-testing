#!/usr/bin/env bash

function usage {
    echo "usage: update-repos [-r repo] [-d code_dir]"
    echo "  -r repo        specify the repo"
    echo "  -b branch      specify the branch used to update the data-model"
    echo "  -p pull_branch specify the rebase branch"
    echo "  -n new_branch  specify the branch you want to create locally and then push to the repo"
    echo "  -t update_type specify the type of update: source or version"
    echo "  -s source_path specify the directory of the source code to update"
    echo "  -d dest_path   specify the directory of the destination code to update"
    return -1
}

function update_sources {
    IFS=';' read -ra ADDR <<< "$DEST_PATH"
    for i in "${ADDR[@]}";
        do
            echo "update files on directory: ${i}"

            # Clean destination contents
            rm -rf "${i}/*"
            # Replace data-model source code
            cp -rf "${SOURCE_PATH}" "${i}"
        done
}

function update_version {
    sed -i "s/iot-data-model v.*/iot-data-model ${version_tag}/" go.mod
    make vendor
}

function update_data_model {
    # Hold current commit hash
    version_tag="$(git describe --abbrev=0)"
    commit_hash="$(git rev-parse --short HEAD)"
    commit_message="Update data-model-protobuf related repos. Commit hash - ${commit_hash}"

    # Git config
    git config --global push.default matching

    # Delete all existing definitions
    git clone -b ${BRANCH} git@github.com:infarm/${REPO}.git
    cd ${REPO}
    git checkout -b ${NEW_BRANCH}-${commit_hash}
    git merge --ff origin/${REBASE_BRANCH}

    if [[ "${UPDATE_TYPE}" == "source" ]]; then
        update_sources
    elif [[ "${UPDATE_TYPE}" == "version" ]]; then
        update_version
    else
        echo "not updating source"
    fi

    #Commit and push
    git add .
    git status

    set +e
    git commit -m "$commit_message"
    set -e
    if (($? == 0)); then
        git push origin ${NEW_BRANCH}-${commit_hash}
        return 0
    fi
    return -2
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
    -b|--branch)
    BRANCH="$2"
    shift # past argument
    shift # past value
    ;;
    -p|--pull_branch)
    REBASE_BRANCH="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--source_path)
    SOURCE_PATH="$2"
    shift # past argument
    shift # past value
    ;;
    -d|--dest_path)
    DEST_PATH="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--update_type)
    UPDATE_TYPE="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--new_branch)
    NEW_BRANCH="$2"
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

if [[ -z "${UPDATE_TYPE}" ]] || [[ -z "${REPO}" ]] || [[ -z "${BRANCH}" ]] || [[ -z "${REBASE_BRANCH}" ]] || [[ -z "${NEW_BRANCH}" ]]; then
    usage
else
    if [[ ( "${UPDATE_TYPE}" == "source" && ( -n "${SOURCE_PATH}" || -n "${DEST_PATH}" ) ) || "${UPDATE_TYPE}" == "version" ]]; then
        update_data_model
    else
        usage
    fi
fi

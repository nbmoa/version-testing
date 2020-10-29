#!/bin/bash -e

createTag() {
    if [[ "$1" != "develop" ]] && [[ "$1" != "master" ]]; then
        echo "ERROR: tagging is only allowed on master and develop branches"
        exit 1
    fi
    BRANCH_TO_TAG="$1"
    if [[ -z "$2" ]]; then
        echo "ERROR: no tag given"
        exit 1
    fi
    NEW_TAG="$2"
    echo "Tagging branch ${BRANCH_TO_TAG} with ${NEW_TAG}"
    git tag -a -m "Created tag ${NEW_TAG}" "${NEW_TAG}" "${BRANCH_TO_TAG}"
    git push -u origin "${NEW_TAG}"
}

getReleaseType() {
    LAST_LOG="$(git log -n 1 --pretty=format:'%s%n%n%b')"
    for TYPE in "release-patch" "release-minor" "release-major"; do
        FOUND_TYPE=$(echo "${LAST_LOG}" | grep "${TYPE}")
        if [[ -n "${FOUND_TYPE}" ]]; then
            echo "${TYPE}"
            return
        fi
    done
}

# retrieve branch name
BRANCH_NAME="$(git branch | sed -n '/\* /s///p')"
VERSION="$(git describe --tags --first-parent --abbrev=0)"

# split into array
VERSION_BITS=(${VERSION//./ })

#get number parts and increase last one by 1
VNUM1="${VERSION_BITS[0]}"
VNUM2="${VERSION_BITS[1]}"
VNUM3="${VERSION_BITS[2]}"
VNUM4="${VERSION_BITS[3]}"

if [[ "${BRANCH_NAME}" == "develop" ]]; then
    VNUM4="$((VNUM4+1))"
    #create new tag
    NEW_VERSION="${VNUM1}.${VNUM2}.0-dev.${VNUM4}"
    echo "Updating ${VERSION} to ${NEW_VERSION}"
    createTag "develop" "${NEW_VERSION}"
elif [[ "${BRANCH_NAME}" == "master" ]]; then
    RELEASE_TYPE="$(getReleaseType)"
    if [[ "${RELEASE_TYPE}" == "release-patch" ]]; then
        VNUM3="$((VNUM3+1))"
        #create new tag
        NEW_VERSION="${VNUM1}.${VNUM2}.${VNUM3}"
        echo "Creating new patch release ${NEW_VERSION}"
        createTag "master" "${NEW_VERSION}"
    elif [[ "${RELEASE_TYPE}" == "release-minor" ]]; then
        VNUM2="$((VNUM2+1))"
        #create new tag
        NEW_MASTER_VERSION="${VNUM1}.${VNUM2}.1"
        NEW_DEVELOP_VERSION="${VNUM1}.${VNUM2}.0-dev.0"
        echo "Creating new minor release ${NEW_MASTER_VERSION}"
        createTag "master" "${NEW_MASTER_VERSION}"
        createTag "develop" "${NEW_DEVELOP_VERSION}"
    elif [[ "${RELEASE_TYPE}" == "release-major" ]]; then
        VNUM1="$((VNUM1+1))"
        #create new tag
        NEW_MASTER_VERSION="${VNUM1}.0.1"
        NEW_DEVELOP_VERSION="${VNUM1}.0.0-dev.0"
        echo "Creating new major release ${NEW_MASTER_VERSION}"
        createTag "master" "${NEW_MASTER_VERSION}"
        createTag "develop" "${NEW_DEVELOP_VERSION}"
    else
        echo "INFO: this commit has no release-patch, release-minor or release-major specified, not creating a new release version"
        exit 0
    fi
else
    echo "ERROR: this script is only allowed to be called for branches develop and master"
    exit 1
fi

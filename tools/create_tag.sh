#!/bin/bash -e

# createTag <branch to tag> <tag string>
# It will create a tag with given string for the specified branch
createTag() {
    if [[ "$1" != "develop" ]] && [[ "$1" != "staging" ]] && [[ "$1" != "master" ]] && [[ "$1" != "test-ci" ]]; then
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
    git tag -a -m "Created tag ${NEW_TAG}" "${NEW_TAG}"
    git push -u origin "${NEW_TAG}"
}

# getActionType
# It will return the action by based on the comment of the PR
getActionType() {
    LAST_LOG="$(git log -n 1 --pretty=format:'%s%n%n%b')"
    for TYPE in "update-rc" "create-minor-rc" "create-major-rc"; do
        FOUND_TYPE=$(echo "${LAST_LOG}" | grep "${TYPE}")
        if [[ -n "${FOUND_TYPE}" ]]; then
            echo "${TYPE}"
            return
        fi
    done
    echo "update-rc"
}

# read out the current branch name and get the latest tag for the branch
# if no proper tag for the branch was found, search in a more generic way and if still no tag was found, assume v0.0.0
BRANCH_NAME="$(git branch | sed -n '/\* /s///p')"
if [[ "${BRANCH_NAME}" == "develop" ]]; then
    LAST_VERSION="$(git describe --tags --first-parent --match "*dev*" --abbrev=0 || true)"
    LAST_RC_VERSION="$(git describe --tags --match "*rc*" origin/staging || true)"
    if [[ -z "${LAST_RC_VERSION}" ]]; then
        LAST_RC_VERSION=v0.0.0-rc.0
    else
        LAST_RC_VERSION=${LAST_RC_VERSION%-rc.*}-rc.0
    fi
    if [[ -z "${LAST_VERSION}" ]]; then
        LAST_VERSION="$(git describe --tags --first-parent  --abbrev=0 || true)"
        if [[ -z "${LAST_VERSION}" ]]; then
            LAST_VERSION=v0.0.0-dev.0
        fi
    fi
    # Handle the special case that the last RC was preparing a new major or minor release
    # if RC version is has a higher base, continue with the base RC version
    echo ${0%/*}/cmp-semver.sh ${LAST_VERSION%-rc*} ${LAST_RC_VERSION%-dev*}
    if [[ "$(${0%/*}/cmp-semver.sh ${LAST_VERSION%-dev*} ${LAST_RC_VERSION%-rc*})" == "-1" ]]; then
        LAST_VERSION="${LAST_RC_VERSION}"
    fi
elif [[ "${BRANCH_NAME}" == "staging" ]]; then
    LAST_VERSION="$(git describe --tags --first-parent --match "*rc*" --abbrev=0 || true)"
    if [[ -z "${LAST_VERSION}" ]]; then
        LAST_VERSION="$(git describe --tags --first-parent  --abbrev=0 || true)"
        if [[ -z "${LAST_VERSION}" ]]; then
            LAST_VERSION=v0.0.0-rc.0
        fi
    fi
elif [[ "${BRANCH_NAME}" == "master" ]]; then
    LAST_VERSION="$(git describe --tags --first-parent --exclude "*dev*" --exclude "*rc*"  --abbrev=0 || true)"
    LAST_RC_VERSION="$(git describe --tags --match "*rc*" --abbrev=0 || true)"
    CURR_COMMIT="$(git describe --tags --first-parent --exclude "*dev*" --exclude "*rc*" || true)"
    if [[ -z "${LAST_VERSION}" ]]; then
        LAST_VERSION="$(git describe --tags --first-parent  --abbrev=0 || true)"
        if [[ -z "${LAST_VERSION}" ]]; then
            LAST_VERSION=v0.0.0
        fi
    fi
    # Ensure for released that the commit has no release assigned yet (in case the CI job is run again
    if [[ "${LAST_VERSION}" == "${CURR_COMMIT}" ]]; then
        echo "INFO: This commit is already the release ${LAST_VERSION}"
        exit 0
    fi
    # Handle the special case that the RC was preparing a new major or minor release
    # Then we need to take the RC candidate version as latest version
    if [[ "$(${0%/*}/cmp-semver.sh ${LAST_VERSION} ${LAST_RC_VERSION})" == "-1" ]]; then
        LAST_VERSION="${LAST_RC_VERSION}"
    fi
elif [[ "${BRANCH_NAME}" == "test-ci" ]]; then
    LAST_VERSION="$(git describe --tags --first-parent --match "*test*" --abbrev=0 || true)"
    if [[ -z "${LAST_VERSION}" ]]; then
        LAST_VERSION="$(git describe --tags --first-parent  --abbrev=0 || true)"
        if [[ -z "${LAST_VERSION}" ]]; then
            LAST_VERSION=v0.0.0
        fi
    fi
fi

# split into array
VERSION_BITS=(${LAST_VERSION//./ })
#get number parts
VNUM1="${VERSION_BITS[0]}"
VNUM2="${VERSION_BITS[1]}"
VNUM3="${VERSION_BITS[2]}"
VNUM4="${VERSION_BITS[3]}"

# calculate new tag string and tag the commit
if [[ "${BRANCH_NAME}" == "develop" ]]; then
    VNUM4="$((VNUM4+1))"
    #create new tag
    NEW_VERSION="${VNUM1}.${VNUM2}.0-dev.${VNUM4}"
    echo "Updating ${LAST_VERSION} to ${NEW_VERSION}"
    createTag "${BRANCH_NAME}" "${NEW_VERSION}"
elif [[ "${BRANCH_NAME}" == "staging" ]]; then
    ACTION_TYPE="$(getActionType)"
    if [[ "${ACTION_TYPE}" == "update-rc" ]]; then
        VNUM4="$((VNUM4+1))"
        #create new tag
        NEW_VERSION="${VNUM1}.${VNUM2}.0-rc.${VNUM4}"
        echo "Updating ${LAST_VERSION} to ${NEW_VERSION}"
        createTag "${BRANCH_NAME}" "${NEW_VERSION}"
    elif [[ "${ACTION_TYPE}" == "create-minor-rc" ]]; then
        VNUM2="$((VNUM2+1))"
        #create new tag
        NEW_STAGING_VERSION="${VNUM1}.${VNUM2}.0-rc.1"
        echo "Creating new minor release ${NEW_STAGING_VERSION}"
        createTag "${BRANCH_NAME}" "${NEW_STAGING_VERSION}"
    elif [[ "${ACTION_TYPE}" == "create-major-rc" ]]; then
        VNUM1_CLEANED="${VNUM1##v}"
        VNUM1="v$((VNUM1_CLEANED+1))"
        #create new tag
        NEW_STAGING_VERSION="${VNUM1}.0.0-rc.1"
        echo "Creating new major release ${NEW_STAGING_VERSION}"
        createTag "${BRANCH_NAME}" "${NEW_STAGING_VERSION}"
    else
        echo "INFO: this commit has no update-rc, create-minor-rc or create-major-rc specified, not creating a new release version"
        exit 0
    fi
elif [[ "${BRANCH_NAME}" == "master" ]]; then
    VNUM3="$((VNUM3+1))"
    #create new tag
    NEW_VERSION="${VNUM1}.${VNUM2}.${VNUM3}"
    echo "Creating new patch release ${NEW_VERSION}"
    createTag "master" "${NEW_VERSION}"
elif [[ "${BRANCH_NAME}" == "test-ci" ]]; then
    VNUM4="$((VNUM4+1))"
    #create new tag
    NEW_VERSION="${VNUM1}.${VNUM2}.0-citest.${VNUM4}"
    echo "Updating ${LAST_VERSION} to ${NEW_VERSION}"
    createTag "test-ci" "${NEW_VERSION}"
else
    echo "ERROR: this script is only allowed to be called for branches develop and master"
    exit 1
fi

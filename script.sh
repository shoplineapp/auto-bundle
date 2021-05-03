#!/bin/sh

set -e

if [ -z "$BITBUCKET_CLIENT_ID" ] || [ -z "$BITBUCKET_SECRET" ]; then
    echo "lack of Bitbucket access key or secret"
    exit 1
fi

cat /opt/atlassian/pipelines/agent/ssh/id_rsa > /root/.ssh/id_rsa && chmod 400 /root/.ssh/id_rsa

git fetch
latest_version=$(git branch -r | grep 'release/' | cut -d '/' -f3 | sort -t. -k 1,1nr -k 2,2nr -k 3,3nr | head -n 1)
origin_branch="release/${latest_version}"
git checkout $origin_branch

branch=feature/${GEM_NAME}-version-${TAG}
git checkout -b "${branch}"

submodule=$(cat Gemfile | grep $GEM_NAME | grep 'path')

if [ -n "$submodule" ]; then
  cd "${GEM_NAME}"
  git fetch
  git checkout "$TAG"
  cd -
  bundle install --path vendor/bundle
  git add "${GEM_NAME}" Gemfile.lock
else
  sed -i -e "s/^\(gem '${GEM_NAME}', git: 'git@bitbucket.org:starlinglabs\/${GEM_NAME}\.git'\),\ \(ref\|TAG\):\ '\([[:alnum:]]\|\.\)\+'/\1, TAG: '${TAG}'/g" Gemfile
  bundle install --path vendor/bundle
  git add Gemfile Gemfile.lock
fi

git commit -m "feat: update ${GEM_NAME} version"
git push origin "${branch}"

repo=$(basename -s .git `git config --get remote.origin.url`)

# get access token
token=$(curl -X POST -u "${BITBUCKET_CLIENT_ID}:${BITBUCKET_SECRET}" \
  https://bitbucket.org/site/oauth2/access_token \
  -d grant_type=client_credentials | jq .access_token -M -r)

response=$(curl --location --request POST "https://api.bitbucket.org/2.0/repositories/starlinglabs/${repo}/pullrequests" \
--header "Authorization: Bearer ${token}" \
--header "Content-Type: application/json" \
--data-raw "{
    \"title\": \"${GEM_NAME} version update\",
    \"state\": \"OPEN\",
    \"open\": true,
    \"closed\": false,
    \"source\": {
        \"branch\": {
            \"name\": \"${branch}\"
        }
    },
    \"destination\": {
        \"branch\": {
            \"name\": \"${origin_branch}\"
        }
    }
}")

type=$(echo "$response" | jq .type -M -r)
if [ "$type" = "error" ]; then
  echo "$response" | jq .error.message
  exit 1
elif [ "$type" = "pullrequest" ]; then
  echo "$response" | jq .links.html.href -r -M
fi
#!/bin/sh

set -e
set -x

if [ -z "$BITBUCKET_CLIENT_ID" ] || [ -z "$BITBUCKET_SECRET" ]; then
    echo "lack of Bitbucket access key or secret"
    exit 1
fi

git config http.${BITBUCKET_GIT_HTTP_ORIGIN}.proxy http://host.docker.internal:29418/
git config remote.origin.fetch "refs/tags/*:refs/tags/*"

origin_branch=$(git rev-parse --abbrev-ref HEAD)
branch=feature/${GEM_NAME}-version-${TAG}
git checkout -b "${branch}"

submodule=$(cat Gemfile | grep $GEM_NAME | grep 'path')

if [ -n "$submodule" ]; then
  cd "${GEM_NAME}"
  git submodule update --init
  git fetch origin
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
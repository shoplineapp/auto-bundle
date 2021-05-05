#!/bin/sh

set -e

if [ -z "$BITBUCKET_CLIENT_ID" ] || [ -z "$BITBUCKET_SECRET" ]; then
    echo "lack of Bitbucket access key or secret"
    exit 1
fi

echo "$SSH_PRIVATE_KEY" | base64 -d > /root/.ssh/id_rsa
chmod 400 /root/.ssh/id_rsa

set -x

git config http.${BITBUCKET_GIT_HTTP_ORIGIN}.proxy http://host.docker.internal:29418/
git config remote.origin.fetch "refs/tags/*:refs/tags/*"

branch=feature/${GEM_NAME}-version-${TAG}
git checkout -b "${branch}"

submodule=$(cat Gemfile | grep $GEM_NAME | grep 'path')

if [ -n "$submodule" ]; then
  git submodule update --init
  cd "${GEM_NAME}"
  git fetch origin
  git checkout "$TAG"
  cd -
  sed -i -e "s/${GEM_NAME} (\([[:digit:]]\|\.\)\+)/${GEM_NAME} (${TAG})/g" Gemfile.lock
  git add "${GEM_NAME}" Gemfile.lock
else
  sed -i -e "s/${GEM_NAME} (\([[:digit:]]\|\.\)\+)/${GEM_NAME} (${TAG})/g" Gemfile.lock
  sed -i -e "s/^\(gem '${GEM_NAME}', git: 'git@bitbucket.org:starlinglabs\/${GEM_NAME}\.git'\),\ \(ref\|tag\):\ '\([[:digit:]]\|\.\)\+'/\1, tag: '${TAG}'/g" Gemfile
  git add Gemfile Gemfile.lock
fi

git commit -m "feat: update ${GEM_NAME} version"
git push origin "${branch}"

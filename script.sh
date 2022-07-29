#!/bin/sh

set -e

echo "$SSH_PRIVATE_KEY" | base64 -d > /root/.ssh/id_rsa
chmod 400 /root/.ssh/id_rsa

if [ -n "$DEBUG" ]; then
  set -x
fi

git config http.${BITBUCKET_GIT_HTTP_ORIGIN}.proxy http://host.docker.internal:29418/
git config remote.origin.fetch "refs/tags/*:refs/tags/*"

branch=feature/${GEM_NAME}-version-${TAG}
git checkout -b "${branch}"

submodule=$(cat Gemfile | grep $GEM_NAME | grep 'path' || true)

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
  sed -i -e "s/^\(\#[[:space:]]*\)*\(gem '${GEM_NAME}'.\+\), tag: '\([[:digit:]]\|\.\)\+'/\2, tag: '${TAG}'/g" Gemfile
  sed -i -e "s/^\(gem '${GEM_NAME}'.\+\, ref: \)/#\1/" Gemfile # comment refs
  git add Gemfile Gemfile.lock
fi

git commit -m "feat: update ${GEM_NAME} version"
git push origin "${branch}"
git checkout -

#!/bin/sh

set -e

echo "$SSH_PRIVATE_KEY" | base64 -d > /root/.ssh/id_rsa
chmod 400 /root/.ssh/id_rsa

if [ -n "$DEBUG" ]; then
  set -x
fi

# for user:root to access .git/
git config --global --add safe.directory '*'
git config http.${BITBUCKET_GIT_HTTP_ORIGIN}.proxy http://host.docker.internal:29418/
git config remote.origin.fetch "refs/tags/*:refs/tags/*"

releaseTag=$(echo "${BITBUCKET_BRANCH#*/}")
branch=feature/bundle-version-for-${releaseTag}
git checkout -b "${branch}"
git submodule update --init

modules=$(echo $GEM_NAME | tr ',' '\n')
for module in $modules; do
  # module: "sl-model:1.123.0"
  moduleName=$(echo $module | cut -d : -f 1)
  moduleVersion=$(echo $module | cut -d : -f 2)
  submodule=$(cat Gemfile | grep $moduleName | grep 'path' || true)

  if [ -n "$submodule" ]; then
    cd "${moduleName}"
    git fetch origin
    git checkout "$moduleVersion"
    cd -
    sed -i -e "s/${moduleName} (\([[:digit:]]\|\.\)\+)/${moduleName} (${moduleVersion})/g" Gemfile.lock
    git add "${moduleName}"
  else
    sed -i -e "s/${moduleName} (\([[:digit:]]\|\.\)\+)/${moduleName} (${moduleVersion})/g" Gemfile.lock
    sed -i -e "s/^\(\#[[:space:]]*\)*\(gem '${moduleName}'.\+\), tag: '\([[:digit:]]\|\.\)\+'/\2, tag: '${moduleVersion}'/g" Gemfile
    sed -i -e "s/^\(gem '${moduleName}'.\+\, ref: \)/#\1/" Gemfile # comment refs
  fi
done

bundle install --without test  #--path vendor/bundle --without test
git add Gemfile Gemfile.lock

git commit -m "feat: bundle version for $releaseTag"
git push -f origin "${branch}"
git checkout -

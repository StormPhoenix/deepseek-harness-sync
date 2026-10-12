#!/usr/bin/env bash
set -euo pipefail
sync_script=$(cd "$(dirname "$0")" && pwd)/sync.sh
root=$(mktemp -d)
trap 'rm -rf -- "$root"' EXIT
export GIT_AUTHOR_NAME=Sync-Test GIT_AUTHOR_EMAIL=sync-test@example.invalid
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

git init -q --initial-branch=master "$root/upstream"
git -C "$root/upstream" -c core.hooksPath=/dev/null commit -qm base --allow-empty
git clone -q --bare "$root/upstream" "$root/fork.git"
git clone -q "$root/fork.git" "$root/work"
git -C "$root/fork.git" update-ref refs/heads/personal/stormphoenix HEAD
personal=$(git -C "$root/fork.git" rev-parse refs/heads/personal/stormphoenix)
git -C "$root/upstream" -c core.hooksPath=/dev/null commit -qm upstream --allow-empty
git -C "$root/upstream" tag light
git -C "$root/upstream" tag -am annotated annotated
bash "$sync_script" "$root/work" "$root/upstream"
[[ $(git -C "$root/fork.git" rev-parse master) == $(git -C "$root/upstream" rev-parse master) ]]
[[ $(git -C "$root/fork.git" rev-parse refs/tags/annotated) == $(git -C "$root/upstream" rev-parse refs/tags/annotated) ]]
[[ $(git -C "$root/fork.git" rev-parse refs/heads/personal/stormphoenix) == "$personal" ]]
bash "$sync_script" "$root/work" "$root/upstream"
echo 'PASS: fast-forward, lightweight/annotated tags, personal branch preservation, idempotence'

before=$(git -C "$root/fork.git" rev-parse master)
git -C "$root/upstream" -c core.hooksPath=/dev/null commit -qm later --allow-empty
git -C "$root/upstream" tag -f light
git -C "$root/upstream" tag new-tag
if bash "$sync_script" "$root/work" "$root/upstream"; then echo 'FAIL: tag conflict accepted'; exit 1; fi
[[ $(git -C "$root/fork.git" rev-parse master) == "$before" ]]
! git -C "$root/fork.git" show-ref --verify --quiet refs/tags/new-tag
echo 'PASS: tag conflict prevents all publication'

git -C "$root/work" reset -q --hard "$before"
git -C "$root/work" -c core.hooksPath=/dev/null commit -qm personal-master --allow-empty
git -C "$root/work" push -q origin master
before=$(git -C "$root/fork.git" rev-parse master)
if bash "$sync_script" "$root/work" "$root/upstream"; then echo 'FAIL: divergence accepted'; exit 1; fi
[[ $(git -C "$root/fork.git" rev-parse master) == "$before" ]]
echo 'PASS: divergent master fails without overwriting'

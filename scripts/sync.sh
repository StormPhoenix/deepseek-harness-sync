#!/usr/bin/env bash
set -euo pipefail

# Only master and upstream tag objects are eligible for publication.
repo=${1:?Usage: sync.sh TARGET_CHECKOUT UPSTREAM_URL}
upstream=${2:?Usage: sync.sh TARGET_CHECKOUT UPSTREAM_URL}
git -C "$repo" fetch --no-tags origin \
  '+refs/heads/master:refs/sync/fork-master' \
  '+refs/tags/*:refs/sync/fork-tags/*'
git -C "$repo" fetch --no-tags "$upstream" \
  '+refs/heads/master:refs/sync/upstream-master' \
  '+refs/tags/*:refs/sync/upstream-tags/*'

fork_head=$(git -C "$repo" rev-parse refs/sync/fork-master)
upstream_head=$(git -C "$repo" rev-parse refs/sync/upstream-master)
if ! git -C "$repo" merge-base --is-ancestor "$fork_head" "$upstream_head"; then
  echo 'ERROR: fork master cannot fast-forward to upstream. No refs were pushed.' >&2
  exit 1
fi

specs=('refs/sync/upstream-master:refs/heads/master')
new_tags=0
while IFS=' ' read -r object ref; do
  tag=${ref#refs/sync/upstream-tags/}
  fork_ref="refs/sync/fork-tags/$tag"
  if git -C "$repo" show-ref --verify --quiet "$fork_ref"; then
    fork_object=$(git -C "$repo" rev-parse "$fork_ref")
    if [[ "$fork_object" != "$object" ]]; then
      printf 'ERROR: conflicting tag %s. No refs were pushed.\n' "$tag" >&2
      exit 1
    fi
  else
    specs+=("$ref:refs/tags/$tag")
    new_tags=$((new_tags + 1))
  fi
done < <(git -C "$repo" for-each-ref --format='%(objectname) %(refname)' refs/sync/upstream-tags/)

# Atomic, non-forced push: concurrent incompatible writes fail without partial updates.
git -C "$repo" push --atomic origin "${specs[@]}"
actual=$(git -C "$repo" ls-remote origin refs/heads/master | cut -f1)
if [[ "$actual" != "$upstream_head" ]]; then
  echo 'ERROR: remote master changed during verification; outcome needs inspection.' >&2
  exit 1
fi
printf 'Synchronized master to %s; published %s new upstream tags.\n' "$upstream_head" "$new_tags"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  printf '## Upstream synchronization\n\n- master: `%s`\n- New tags: %s\n- Personal branches and extra fork tags: untouched\n' \
    "$upstream_head" "$new_tags" >> "$GITHUB_STEP_SUMMARY"
fi

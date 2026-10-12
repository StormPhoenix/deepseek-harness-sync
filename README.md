# DeepSeek Harness fork synchronization

This independent repository runs GitHub Actions to synchronize `StormPhoenix/deepseek-harness` from `deepseek-ai/deepseek-harness`. It does not add commits to the fork.

## Execution

The workflow checks every hour at minute 17 UTC (also minute 17 in Asia/Shanghai), subject to GitHub scheduling delays. Open Actions → Sync DeepSeek Harness upstream → Run workflow for an immediate check. GitHub may disable scheduled workflows after 60 days without repository activity; re-enable the workflow if that happens.

`FORK_SYNC_DEPLOY_KEY` is an Actions secret containing a dedicated SSH private key. Its public key is registered as a write-enabled Deploy Key only on the target fork. No personal access token or account-wide authorization is used. The target repository must permit direct fast-forward pushes to master; branch rules are never bypassed.

## Safety rules

- master updates only by fast-forward and ends at the exact upstream commit SHA fetched for that run.
- Upstream lightweight and annotated tags retain their exact Git object IDs.
- Conflicting tags or divergent master history fail before any push.
- Publication uses a single atomic, non-forced push. Concurrent incompatible updates fail rather than overwrite refs.
- Personal branches, additional fork tags, and upstream tag deletions are not synchronized or deleted.
- Upstream source code and its workflows are not executed by the synchronization job.
- The workflow writes only master and upstream tags; it never uses mirror push.
- A final remote master check detects changes during verification. Actions failures remain visible in the run log.

Only the GitHub fork is updated. Local worktrees are unchanged. To update a clean local master, fetch origin and fast-forward it separately.

## Administration

To pause synchronization, disable the workflow in Actions. To revoke access, remove the `upstream-sync-automation` Deploy Key from the target fork and delete `FORK_SYNC_DEPLOY_KEY` from this repository's Actions secrets. Removing the key prevents future writes without affecting personal branches.

Public automation repositories use GitHub-hosted standard runners without consuming private-repository Actions minutes. Never include private keys or tokens in commits.

# Fresh Repo Bootstrap

Read this file only when the repository still looks freshly copied from
`stable-ai-dev-template/`, for example when repo identity docs still point to
the template source or copied template task history is still present.

## Bootstrap Trigger

- run `bash scripts/init-project.sh` before feature planning or implementation.
- If the user says things like "프로젝트 셋팅부터 하자", "프로젝트 세팅부터 하자", or "start with project setup", treat that as authorization to run the bootstrap flow immediately.
- Prefer running `bash scripts/init-project.sh` without asking the user to remember commands. Infer the provisional project name from the repo directory when the user has not named it yet, then report what was inferred.

## Bootstrap Scope

- During this bootstrap-only phase, keep scope limited to git/base-branch setup, repo identity docs, CI profile generation, and creating the initial `project-bootstrap` task.
- Do not widen the bootstrap task into product features, roadmap work, or unrelated refactors.

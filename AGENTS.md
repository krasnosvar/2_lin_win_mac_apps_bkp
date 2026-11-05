# Agent instructions — offline backup

This repository is an English-language backup utility, not a course.
`apps.tsv` is the installer manifest; `scripts/backup.sh` also backs
up container images and Python/Go packages. It and
`scripts/backup.ps1` download artifacts, and
`scripts/homedir_configs_bkp.sh` archives workstation configuration.
Read the relevant script, manifest and README before changing behavior.

- Use a separate task branch in this checkout. Preserve unrelated changes;
  do not stash, reset, clone or create worktrees automatically.
- Preserve existing data and backup archives. Do not run downloads,
  restore commands, or a real home-directory backup merely to test an edit.
- `--with-secrets` includes credentials: never expose archive contents or
  credentials in output or Git. Do not treat a secret backup as a fixture.
- For shell changes run `bash -n` on affected scripts and use isolated,
  non-network fixtures for behavioral checks. Check PowerShell separately
  when available; say explicitly when a platform was not tested.
- Keep the manifest format, command options and README aligned. Verify
  counts against the actual data before publishing numerical claims.
- Do not commit without an explicit user request.

## Каталоги tests

Не создавай каталоги с именем `tests` в репозиториях этой серии.
Не удаляй проверки: размещай их рядом с проверяемыми файлами или
в существующих упражнениях и обновляй команды и CI при переносе.

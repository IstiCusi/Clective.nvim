# Changelog

## GitHub preparation — 2026-11-19

- Preserve the original implementation and all local development commits.
- Merge the repository's initial GitHub commit without rewriting either history.
- Add a repository-based Lazy specification, standalone clangd example and migration guide.
- Separate personal SDK settings and local configuration installers from the public plugin.
- Add MIT licensing, contribution notes and pinned GitHub Actions tests.
- Register the completion source when nvim-cmp is loaded after Clective.
- Verify persisted file overrides across separate Neovim processes.

## Local profile update — 2026-11-18

- Replace one global include-set selection with coupled language/SDK profiles.
- Persist project and file choices outside the plugin directory.
- Resolve ambiguous .h files using profile/build/source context.
- Read compilation databases and flags files, including paths with spaces.
- Query explicitly configured native compilers for system include paths.
- Update attached clangd clients; add project indexing and source/header switch.
- Preserve nested include paths and support empty prefixes/extensionless headers.
- Scope cmp source changes to includes and preserve unrelated buffer settings.
- Share context between header navigation, picker, status line and clangd.
- Add inspection, health checks, a runnable demo and regression tests.
- Integrate the existing phonon shortcuts/status line with a backup installer.

# Local profile update

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

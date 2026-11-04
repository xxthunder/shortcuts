# Shortcuts: release branch

This branch holds the files that users of the px-proxy tool, WSL Manager and the Scoop
update helper need, and nothing else. CI builds it from `develop` (`bin/release/Build-Release.ps1`);
every commit reads `release: build from <develop sha>`.

Do not edit this branch and do not open pull requests against it. The next build replaces
every change.

The source, the tests and the documentation live on `develop` at
https://github.com/xxthunder/shortcuts.

## Use it in a fork

Vendor the branch into your repository with `git subtree`:

```
git subtree add --prefix=<dir> --squash https://github.com/xxthunder/shortcuts.git release
```

Take later builds in with the same arguments:

```
git subtree pull --prefix=<dir> --squash https://github.com/xxthunder/shortcuts.git release
```

## License

MIT, see [LICENSE](LICENSE).

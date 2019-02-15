# helm nexus plugin

Helm plugin to using Sonatype Nexus OSS as your private charts repository.

## Install

Based on the version in plugin.yaml, release binary will be downloaded from GitHub:

```
$ helm plugin install https://github.com/yisiqi/helm-nexus
```

## Usage

Start by adding a repo via Helm CLI (if not already added)

```
$ helm repo add --username xxxx --password xxxx charts-private https://example.com/repository/charts
```

For all available plugin options, please run

```
$ helm nexus --help
```

### Package your charts

Here is an example packaging the chart files under `./charts/`. This will try to package every valid charts directory under default path with the `helm package` command.

```
$ helm nexus package
```

Also you can specified your own path, or use `helm package` command directly.


```
$ helm nexus package ./my-charts/
```

### Publish charts

This command will meger index, then upload the archived package and the new index file. The `./charts/` directory will be searched by default.

```
$ helm nexus publish my-charts-repo-name
```

Also you can specified your own path

```
$ helm nexus publish ./my-charts my-charts-repo-name
```

If you do not specify a repository name, the first repository will be used as the publish target by default.

```
# Publish every charts under `./charts/` to the first repository in `$HELM_HOME/repository/repositories.yaml`

$ helm nexus publish
```
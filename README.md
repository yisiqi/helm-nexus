# helm nexus plugin

A helm plugin to use Sonatype Nexus OSS as your private charts repository.

## Install

Based on the version specified in `plugin.yaml`, corresponding release binary will be downloaded from GitHub with command:

```
$ helm plugin install https://github.com/yisiqi/helm-nexus.git
```

## Usage

Start by adding a repo via Helm CLI (if not added yet)

```
$ helm repo add --username xxxx --password xxxx charts-private https://example.com/repository/charts
```

For all available plugin options, please run

```
$ helm nexus --help
```

### Package your charts

You can run `helm package` command to package chart files. Every valid charts directory will be packaged under a certain path (`./charts/` would be the default path if no path specified).

```
$ helm nexus package
```

Also, you can specify your own path.


```
$ helm nexus package ./my-charts/
```

### Publish charts

This command will merge index, then upload the archived package and the new index file. The `./charts/` directory will be searched by default.

```
$ helm nexus publish my-charts-repo-name
```

Also you can specify your own path

```
$ helm nexus publish ./my-charts my-charts-repo-name
```

If you do not specify a repository name, the first repository will be used as the publish target by default.

```
# Publish every charts under `./charts/` to the first repository in `$HELM_HOME/repository/repositories.yaml`

$ helm nexus publish
```

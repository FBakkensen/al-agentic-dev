# Breaking-change baselines from Azure Repos

Research for [issue #11](https://github.com/FBakkensen/al-agentic-dev/issues/11). Checked on 2026-09-27 against Microsoft Learn, BcContainerHelper `main`, and AL-Go `main`.

## Question

`/al-build` gets the breaking-change baseline by running `gh release download` against the consumer repository's latest GitHub release. Consumer repositories now live in Azure Repos (ADR 0001). This note asks what can serve the previous release's `.app` and its dependencies instead, and how each option authenticates unattended from a developer machine and from Azure Pipelines.

## Recommendation

**Use an Azure Artifacts NuGet feed that follows the Business Central NuGet convention.** Publish each released app with BcContainerHelper's `New-BcNuGetPackage`, then promote it to the feed's `@Release` view. `download-baseline.ps1` fills the baseline cache with BcContainerHelper's `Download-BcNuGetPackageToFolder`, reading from `https://pkgs.dev.azure.com/<org>/[<project>/]_packaging/<feed>@Release/nuget/v3/index.json`.

For the token:

- On a developer machine, use a Microsoft Entra token from `az account get-access-token`, so no PAT is needed.
- In Azure Pipelines, use `$(System.AccessToken)` mapped into the step's environment.

Why this option wins:

1. **"Latest release" keeps its meaning.** The `@Release` view shows only promoted versions, which matches `gh release view`: the latest release, not the latest build. Universal Packages can't do this from the CLI (see the Universal Packages section).
2. **The version format matches.** NuGet versions carry a fourth `Revision` segment natively. Universal Packages require three-part SemVer.
3. **Dependencies come with the package.** A BC NuGet package records its app dependencies. `Download-BcNuGetPackageToFolder -downloadDependencies own|allButMicrosoft` fetches the app and its dependency closure into one folder. That replaces the release loop plus the AL-Go `appDependencyProbingPaths` loop, which Azure Repos consumers have no `.AL-Go/settings.json` for.
4. **It follows Microsoft's direction.** BcContainerHelper, AL-Go (`trustedNuGetFeeds`, `trustMicrosoftNuGetFeeds`), and Microsoft's own symbol feeds all use this package format.
5. **Auth was checked against Naveksa's organization.** `az login` → Entra token → `Authorization: Basic user:<token>` returned 200 from Naveksa's org feed, including the NuGet v3 index of its `@Release` view. That header is exactly what BcContainerHelper sends.

Trade-offs:

- Every consumer repository needs a release pipeline step that packs and pushes the NuGet package, then promotes it.
- BcContainerHelper labels its NuGet functions "PROOF OF CONCEPT PREVIEW".
- The download depends on BcContainerHelper. `validate-breaking-changes.ps1` already imports it, so this adds no new tool.

## Options compared

| | Azure Artifacts NuGet (BC convention) | Azure Artifacts Universal Package | Pipeline artifact of last release run | Git tag with attached file |
|---|---|---|---|---|
| Stores a `.app`? | Yes, `.app` inside `.nupkg` | Yes, any files | Yes | **No.** Azure Repos tags carry no files |
| "Latest *release*" (not latest build) | `@Release` view URL | Latest published only; CLI has no view parameter | Needs pipeline ID + branch + result filter + tag convention | n/a |
| 4-part BC version | Native (`Revision`) | **No**: SemVer, 3 parts | n/a (run IDs) | n/a |
| Dependencies | In package metadata; resolved by `Download-BcNuGetPackageToFolder` | Must be bundled or fetched separately | Must be bundled | n/a |
| Lifetime | Feed retention (configurable) | Feed retention | **Deleted with the run** under pipeline retention | n/a |
| Dev-machine auth | Entra token via `az account get-access-token` (verified), or PAT | `az login` / `az devops login` / `AZURE_DEVOPS_EXT_PAT` | Same as Universal | n/a |
| Pipeline auth | `System.AccessToken` (build identity needs a feed reader role) | `System.AccessToken` piped to `az devops login`, or `AzureCLI@3` with an Azure DevOps service connection | Same as Universal | n/a |
| Tooling | BcContainerHelper (already used) | az CLI + `azure-devops` extension | az CLI + `azure-devops` extension | n/a |

### Azure Artifacts NuGet feed (recommended)

- **Package format.** `New-BcNuGetPackage` defaults `packageId` to `{publisher}.{name}.{id}` ([source](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/New-BcNuGetPackage.ps1)). `Get-BcNuGetPackageId` fills a `'{publisher}.{name}.{tag}.{id}'` template and caps the ID at 100 characters ([source](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/Get-BcNuGetPackageId.ps1)).
- **Download into a folder.** `Download-BcNuGetPackageToFolder` takes these parameters ([source](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/Download-BcNuGetPackageToFolder.ps1)):
  - `nuGetServerUrl`, `nuGetToken`, `packageName`, `version`, `folder`
  - `version` accepts NuGet version ranges
  - `select`: `Latest`, `Exact`, and others
  - `downloadDependencies`: `all`, `own`, `allButMicrosoft`, `allButApplication` (the default), `allButPlatform`, or `none`
- **Auth header.** BcContainerHelper's `NuGetFeed.GetHeaders()` sends `Authorization: Basic base64("user:<token>")` to every host except `api.nuget.org` ([source](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/NuGetFeedClass.ps1)). So any token Azure DevOps accepts through Basic auth works.
- **Branch-aware baselines.** AL-Go picks the latest release *for the target branch*. To keep that behaviour, pass a version range such as `[25.0,26.0)` for a release line, or use one view per line. NuGet range syntax is on the [NuGet versioning page](https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges).
- **Version normalization.** NuGet drops a zero fourth part, so `1.0.0.0` is treated as `1.0.0` ([NuGet normalization](https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#normalized-version-numbers)). `Get-BaselineVersion` must therefore keep reading the version from the `.app` filename first, and a package version must never replace it, or AS0003 comes back.
- **Views.** Every feed has `@Local`, `@Prerelease`, and `@Release`. Publishing only goes to the base feed (`@Local`), and packages are then promoted to a view ([feed views](https://learn.microsoft.com/en-us/azure/devops/artifacts/concepts/views?view=azure-devops)).
- **Why the Azure Artifacts Credential Provider doesn't apply.** It is a NuGet plugin for nuget.exe, dotnet, and MSBuild ([NuGet.exe setup](https://learn.microsoft.com/en-us/azure/devops/artifacts/nuget/nuget-exe?view=azure-devops)). BcContainerHelper calls the feed with `Invoke-RestMethod`, so the credential provider never reaches it. Pass the token explicitly instead. For Entra service principals, the credential provider's `ARTIFACTS_CREDENTIALPROVIDER_FEED_ENDPOINTS` covers only those NuGet clients.
- **Microsoft's public symbol feeds use the same format.** AL-Go's `trustMicrosoftNuGetFeeds` adds `https://dynamicssmb2.pkgs.visualstudio.com/DynamicsBCPublicFeeds/_packaging/AppSourceSymbols/nuget/v3/index.json` ([AL-Go RunPipeline.ps1](https://github.com/microsoft/AL-Go/blob/main/Actions/RunPipeline/RunPipeline.ps1)). The AL extension's "Download symbols from global sources" reads Microsoft's NuGet feeds too. Its custom feeds (`al.nugetFeeds`) "should be public NuGet v3 feeds without authentication" ([BC 2026 wave 1 release plan](https://learn.microsoft.com/en-us/dynamics365/release-plan/2026wave1/smb/dynamics365-business-central/download-symbols-nuget-feed)). The AL extension therefore can't read a private Naveksa feed; the baseline fetch has to stay in `/al-build`'s scripts.

### Azure Artifacts Universal Package

- **Download command.** `az artifacts universal download --feed --name --version --path [--scope project|organization] [--project] [--org] [--file-filter]`. It has no view parameter ([CLI reference](https://learn.microsoft.com/en-us/cli/azure/artifacts/universal)).
- **Latest version.** `--version '*'` downloads the latest version, and `'1.*'` the latest in major 1. "Wildcard patterns are not supported with prerelease versions" ([download quickstart](https://learn.microsoft.com/en-us/azure/devops/artifacts/quickstarts/download-universal-packages?view=azure-devops)). The same page says there is no direct REST download endpoint; the Azure CLI is required.
- **No view targeting.** Downloading the latest version from `@Release` was requested in [azure-cli-extensions#2330](https://github.com/Azure/azure-cli-extensions/issues/2330) and is not in the documented parameters. Passing `--feed <feed>@Release` circulates as a workaround, but no Microsoft source documents it.
- **Version format.** The package version must be lowercase with no build metadata, following SemVer 2.0 ([publish quickstart](https://learn.microsoft.com/en-us/azure/devops/artifacts/quickstarts/universal-packages)). A BC `1.2.3.4` therefore needs a mapping, and only the `.app` filename can carry the true version.
- **Hosting.** Universal Packages are available only in Azure DevOps Services ([pipelines doc](https://learn.microsoft.com/en-us/azure/devops/pipelines/artifacts/universal-packages?view=azure-devops)).
- **Why it's the fallback.** It is the simplest option to publish (one `az` command or the `UniversalPackages@0` task), but it can serve only "latest published".

### Pipeline artifact from the last release run

- **Commands.** Find the run with `az pipelines runs list --pipeline-ids <id> --branch <b> --result succeeded --status completed --tags <tag> --query-order FinishTimeDesc --top 1`, then fetch with `az pipelines runs artifact download --run-id --artifact-name --path` ([runs](https://learn.microsoft.com/en-us/cli/azure/pipelines/runs), [artifact](https://learn.microsoft.com/en-us/cli/azure/pipelines/runs/artifact)).
- **Retention is disqualifying.** Deleting a run removes "All pipeline and build artifacts", and pipeline run retention doesn't govern Universal Packages or NuGet ([retention](https://learn.microsoft.com/en-us/azure/devops/pipelines/policies/retention?view=azure-devops)). A baseline that disappears when retention runs, unless someone keeps a retention lease, is a silent path to "no baseline".
- **Setup cost.** Each consumer would also have to configure a pipeline ID, an artifact name, and a tag convention.

### Git tags with attached files

Azure Repos supports lightweight and annotated tags. An annotated tag holds only the tagger, message, and date ([Azure Repos tags](https://learn.microsoft.com/en-us/azure/devops/repos/git/git-tags?view=azure-devops)). Azure Repos has no counterpart to GitHub release assets. A tag can tell you *which* version is the baseline, but it can't serve the `.app`. Committing `.app` files to the repository would work, but it puts build output in source control.

## Authentication, unattended

| Context | NuGet feed (recommended) | az CLI routes (Universal, pipeline artifacts) |
|---|---|---|
| Developer machine | `az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv` → `nuGetToken`. **Verified 2026-09-27:** Basic and Bearer both returned 200 on `naveksaas` feeds and on the `@Release` NuGet v3 index. Fallback: PAT with Packaging (read). | `az login` covers `az devops` commands. Otherwise run `az devops login` or set `AZURE_DEVOPS_EXT_PAT` ([PAT sign-in](https://learn.microsoft.com/en-us/azure/devops/cli/log-in-via-pat)). |
| Azure Pipelines | Map `SYSTEM_ACCESSTOKEN: $(System.AccessToken)` in the step's `env`; YAML requires this mapping explicitly ([predefined variables](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops)). Pass it as `nuGetToken`. Basic auth with `System.AccessToken` was not tested in a pipeline here. Bearer is the documented form, so fall back to a direct Bearer REST call if Basic fails. | `echo $(System.AccessToken) \| az devops login --organization …`, or `AzureCLI@3` with `connectionType: azureDevOps` and workload identity federation ([PAT sign-in](https://learn.microsoft.com/en-us/azure/devops/cli/log-in-via-pat)). |
| Feed permissions | By default the Project Collection Build Service and the project Build Service get **Feed and Upstream Reader (Collaborator)**. Publishing requires **Feed Publisher (Contributor)** on both. A project-scoped build identity reading a feed in another project needs extra grants ([feed permissions](https://learn.microsoft.com/en-us/azure/devops/artifacts/feeds/feed-permissions?view=azure-devops)). | Same identities. |

On an auth failure the script should keep today's contract: exit `$Exit.Contract` with the exact command the user runs, which is `az login`, not `gh auth login --hostname …`.

## Prior art: how AL-Go and BcContainerHelper get the previous release

- AL-Go's `DownloadPreviousRelease` action calls `GetLatestRelease` against the GitHub API for the base/ref branch and unpacks the release's `Apps` assets into `.previousRelease` ([source](https://github.com/microsoft/AL-Go/blob/main/Actions/DownloadPreviousRelease/DownloadPreviousRelease.ps1), [README](https://github.com/microsoft/AL-Go/blob/main/Actions/DownloadPreviousRelease/README.md)). It works only on GitHub, which leaves nothing to reuse for Azure Repos.
- AL-Go's `RunPipeline.ps1` passes those files as `previousApps`. If none are found, it warns that this "also disables the AppSourceCop breaking change check" ([source](https://github.com/microsoft/AL-Go/blob/main/Actions/RunPipeline/RunPipeline.ps1)). `skipUpgrade` turns the lookup off ([AL-Go settings](https://github.com/microsoft/AL-Go/blob/main/Scenarios/settings.md)).
- BcContainerHelper's `Run-AlPipeline -previousApps` accepts only files or a list; it never fetches them itself ([source](https://github.com/microsoft/navcontainerhelper/blob/main/AppHandling/Run-AlPipeline.ps1)).
- AppSourceCop needs the previous version (`version`, optionally with `name` and `publisher`) in the `baselinePackageCachePath` folder ([AppSourceCop](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/analyzers/appsourcecop)). This part is independent of where the file comes from, so `Set-AppSourceCopBaseline` and `Clear-AppSourceCopBaseline` stay as they are.

## What would change in `/al-build` (description only)

**`skills/al-build/scripts/download-baseline.ps1`**
- Remove the gh CLI check, `Get-GhTargetHostName`, `Test-GhAuthentication`, `gh release view --json tagName,assets`, and the probing-path loop that uses `Get-RepoFromUrl` / `Test-GhHostAuthentication` / `Get-ReleaseAppFiles -Repo`.
- Add these steps:
  1. Resolve the feed URL from config.
  2. Get a token: `SYSTEM_ACCESSTOKEN` if set, else `az account get-access-token`. A missing `az` exits `$Exit.MissingTool`.
  3. Call `Download-BcNuGetPackageToFolder -packageName <derived id> -version <range> -select Latest -downloadDependencies own -folder $cacheDir`.
- Keep the no-package path: "not found" clears `version` from AppSourceCop.json and the cache, then exits 0. It needs a new detector, because an empty NuGet search result replaces the empty `gh release view`.
- Keep the Microsoft platform symbols copy, `Get-BaselineVersion` (filename first), and `Set-AppSourceCopBaseline` unchanged.
- The `-ReleaseTag` fallback in `Get-BaselineVersion` becomes the package version. It is safe only as a fallback, because NuGet normalizes the version (see above).

**`skills/al-build/scripts/common.psm1`**
- Replace the "GitHub CLI Integration" section:
  - `Get-GhTargetHostName` → an Azure Repos resolver that reads org and project from `origin`. It must handle `https://dev.azure.com/<org>/<project>/_git/<repo>`, `https://<org>.visualstudio.com/…`, and `git@ssh.dev.azure.com:v3/<org>/<project>/<repo>`. Today's `Get-RepoFromUrl` throws on the four-segment `_git` form.
  - `Test-GhAuthentication` / `Test-GhHostAuthentication` → a token probe against the Azure DevOps resource.
  - `Get-ReleaseAppFiles` → a NuGet download wrapper.
- `Get-AlGoDependencyProbingPaths` no longer feeds the baseline, because NuGet dependency metadata replaces it.
- `Install-AlGoDependencies`, used by `new-bc-container.ps1`, shares the same gh path. It is out of scope here, but it will need the same replacement.
- Update the module's export list to match.

**`skills/al-build/scripts/build-operations.psm1`**
- Add new keys to `Resolve-BreakingChangeValue` and `ALBT_*` overrides to `Set-BuildEnvironment`. Suggested keys, all under `breakingChange`:
  - `feedUrl`, or `organization` + `project` + `feed`
  - `view` (default `Release`)
  - `packageId` (default derived from app.json as `{publisher}.{name}.{id}`)
  - `versionRange` (default: any)
  - `downloadDependencies` (default `own`)

**`skills/al-build/config/al-build.json`**: add the same keys, with defaults, under `breakingChange`.

**`skills/al-build/SKILL.md`**: line 45 (`provision.ps1` "caches the previous release"), line 56 (`download-baseline.ps1`), and line 62 (the list of config fields that change behaviour) need to name the feed and the `az login` prerequisite.

**Tests**
- `tests/al-build/GhAuthentication.Tests.ps1` retires or moves to the new token probe.
- `tests/al-build/Get-RepoFromUrl.Tests.ps1` gains Azure Repos URL cases, or a sibling parser gets its own tests.
- `tests/al-build/BreakingChangeBaseline.Tests.ps1` changes wherever it mocks the release fetch.

**Release side (consumer pipeline, not this plugin):** after a release build, run `New-BcNuGetPackage` for each app, `Push-BcNuGetPackage` to the feed with `System.AccessToken`, then promote the version to `@Release`. Both build identities need Feed Publisher (Contributor).

## Decision for the user

The recommendation needs one Naveksa-side decision: **which feed holds released apps**.

- **(a)** The existing org-scoped `naveksaas` feed. **Recommended:** it already exists, and org-scoped feeds avoid cross-project build-identity grants.
- **(b)** A new dedicated release feed.
- **(c)** One project-scoped feed per consumer repository.

The script design is the same for all three; only the default `feedUrl` changes.

## Sources

- Azure Artifacts: [publish Universal Packages](https://learn.microsoft.com/en-us/azure/devops/artifacts/quickstarts/universal-packages), [download Universal Packages](https://learn.microsoft.com/en-us/azure/devops/artifacts/quickstarts/download-universal-packages?view=azure-devops), [`az artifacts universal`](https://learn.microsoft.com/en-us/cli/azure/artifacts/universal), [Universal Packages in Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/artifacts/universal-packages?view=azure-devops), [feed views](https://learn.microsoft.com/en-us/azure/devops/artifacts/concepts/views?view=azure-devops), [feed permissions](https://learn.microsoft.com/en-us/azure/devops/artifacts/feeds/feed-permissions?view=azure-devops), [NuGet.exe + credential provider](https://learn.microsoft.com/en-us/azure/devops/artifacts/nuget/nuget-exe?view=azure-devops), [azure-cli-extensions#2330](https://github.com/Azure/azure-cli-extensions/issues/2330)
- Azure Pipelines / CLI: [`az pipelines runs`](https://learn.microsoft.com/en-us/cli/azure/pipelines/runs), [`az pipelines runs artifact`](https://learn.microsoft.com/en-us/cli/azure/pipelines/runs/artifact), [retention](https://learn.microsoft.com/en-us/azure/devops/pipelines/policies/retention?view=azure-devops), [predefined variables / System.AccessToken](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables?view=azure-devops), [CLI PAT sign-in](https://learn.microsoft.com/en-us/azure/devops/cli/log-in-via-pat)
- Azure Repos: [Git tags](https://learn.microsoft.com/en-us/azure/devops/repos/git/git-tags?view=azure-devops)
- NuGet: [package versioning](https://learn.microsoft.com/en-us/nuget/concepts/package-versioning)
- Business Central: [AppSourceCop](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/analyzers/appsourcecop), [download symbols from NuGet feed (2026 wave 1)](https://learn.microsoft.com/en-us/dynamics365/release-plan/2026wave1/smb/dynamics365-business-central/download-symbols-nuget-feed), [al_downloadsymbols](https://learn.microsoft.com/en-us/dynamics365/business-central/dev-itpro/developer/al-agent-tools/al-tool-download-symbols)
- BcContainerHelper: [New-BcNuGetPackage](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/New-BcNuGetPackage.ps1), [Get-BcNuGetPackageId](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/Get-BcNuGetPackageId.ps1), [Download-BcNuGetPackageToFolder](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/Download-BcNuGetPackageToFolder.ps1), [NuGetFeedClass](https://github.com/microsoft/navcontainerhelper/blob/main/NuGet/NuGetFeedClass.ps1), [Run-AlPipeline](https://github.com/microsoft/navcontainerhelper/blob/main/AppHandling/Run-AlPipeline.ps1)
- AL-Go: [DownloadPreviousRelease](https://github.com/microsoft/AL-Go/blob/main/Actions/DownloadPreviousRelease/DownloadPreviousRelease.ps1), [RunPipeline.ps1](https://github.com/microsoft/AL-Go/blob/main/Actions/RunPipeline/RunPipeline.ps1), [settings](https://github.com/microsoft/AL-Go/blob/main/Scenarios/settings.md)

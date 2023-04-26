# Hutte Recipe - CI/CD Incremental Deployment

> This recipe uses [sfdx-git-delta](https://github.com/scolladon/sfdx-git-delta) to incrementally deploy changes.

> **Note** PRs need to be merged via "Create a merge commit" or "Squash and merge" option to correctly detect the changes.

## Prerequisites

- a GitHub repository with a valid sfdx project
- a target org authenticated with sfdx locally

## Steps

### Step 1

Create the following three GitHub Workflows:

`.github/workflows/incremental-deploy.yml`

```yaml
# Based on https://github.com/mehdisfdc/sfdx-GitHub-actions/blob/main/.github/workflows/main.yml
name: Incremental deployment

on:
  workflow_dispatch:
    inputs:
      validateOnly:
        description: "Perform a validation deployment only"
      baseRef:
        description: "Git base ref"
        required: true
      targetRef:
        description: "Git target ref"
        required: true
  workflow_call:
    inputs:
      validateOnly:
        description: "Perform a validation deployment only"
        type: boolean
      baseRef:
        description: "Git base ref"
        type: string
        required: true
      targetRef:
        description: "Git target ref"
        type: string
        required: true

jobs:
  default:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Install sfdx
        run: |
          npm install --global sfdx-cli
          sfdx --version
      - name: Generate delta
        run: |
          echo y | sfdx plugins:install sfdx-git-delta
          if [ "${{ inputs.validateOnly }}" = "true" ]; then
            git merge "${{ inputs.baseRef }}"
          fi
          mkdir -p deltas
          sfdx sgd:source:delta --from "${{ inputs.baseRef }}" --to "${{ inputs.targetRef }}" --output deltas --generate-delta --ignore .forceignore
          echo "# package.xml"
          cat deltas/package/package.xml; echo ""
          echo "# destructiveChanges.xml"
          cat deltas/destructiveChanges/destructiveChanges.xml; echo ""
      - name: Deploy changes to target org
        run: |
          sfdx org login sfdx-url --set-default --sfdx-url-file <(echo "${{ secrets.SFDX_AUTH_URL_TARGET_ORG }}")
          deployFlags=(
            --manifest deltas/package/package.xml
            --postdestructivechanges deltas/destructiveChanges/destructiveChanges.xml
            --wait 30
            --testlevel RunLocalTests
            --verbose
          )
          if [ "${{ inputs.validateOnly }}" = "true" ]; then
            deployFlags+=( --checkonly )
          fi
          sfdx force:source:deploy "${deployFlags[@]}"
```

`.github/workflows/pr.yml`

```yaml
name: Pull Request

on:
  pull_request:

jobs:
  incremental-deploy:
    name: Run Incremental Deploy Workflow
    uses: ./.github/workflows/incremental-deploy.yml
    secrets: inherit
    with:
      baseRef: "origin/${GITHUB_BASE_REF}"
      targetRef: "HEAD"
      validateOnly: true
```

`.github/workflows/main.yml`

```yaml
name: Main

on:
  push:
    branches:
      - main

jobs:
  incremental-deploy:
    name: Run Incremental Deploy Workflow
    uses: ./.github/workflows/incremental-deploy.yml
    secrets: inherit
    with:
      # Note: This requires the merged PR to only have a single commit or merge commit
      baseRef: "HEAD~1"
      targetRef: "HEAD"
```

### Step 2

Copy the value of `sfdxAuthUrl` to the clipboard.

```console
sfdx org display --verbose --json -o <MY_TARGET_ORG_ALIAS>
```

Create a GitHub Action Secret (`Settings > Secrets and variables > Actions > New repository secret`):

| Name                       | Secret                         |
| -------------------------- | ------------------------------ |
| `SFDX_AUTH_URL_TARGET_ORG` | <PASTE_THE_SFDX_AUTH_URL_HERE> |

### Step 3

- Create a PR and verify the Action was run successfully
- Merge the PR and verify the Action was run successfully

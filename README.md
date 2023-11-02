## Prerequisites

- a GitHub repository with a valid sfdx project
- a target org authenticated with sfdx locally

## Step 1: Create GitHub Workflows

Create the following three GitHub Workflow files:

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
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Install Salesforce CLI
        run: |
          npm install --global @salesforce/cli
          sf version
      - name: Generate delta
        run: |
          echo y | sf plugins:install sfdx-git-delta
          if [ "${{ inputs.validateOnly }}" = "true" ]; then
            git merge "${{ inputs.baseRef }}"
          fi
          mkdir -p deltas
          sf sgd:source:delta --from "${{ inputs.baseRef }}" --to "${{ inputs.targetRef }}" --output deltas --generate-delta --ignore .forceignore
          echo "# package.xml"
          cat deltas/package/package.xml; echo ""
          echo "# destructiveChanges.xml"
          cat deltas/destructiveChanges/destructiveChanges.xml; echo ""
      - name: Deploy changes to target org
        run: |
          sf org login sfdx-url --set-default --sfdx-url-file <(echo "${{ secrets.SFDX_AUTH_URL_TARGET_ORG }}")
          deployFlags=(
            --manifest deltas/package/package.xml
            --post-destructive-changes deltas/destructiveChanges/destructiveChanges.xml
            --wait 30
            --test-level RunLocalTests
            --verbose
          )
          if [ "${{ inputs.validateOnly }}" = "true" ]; then
            deployFlags+=( --dry-run )
          fi
          sf project deploy start "${deployFlags[@]}"
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

## Step 2: Copy Auth URL to the clipboard.

Run the following code to obtain the Auth URL of the Salesforce Org you would like to deploy to:

```console
sfdx org display --verbose --json -o <MY_TARGET_ORG_ALIAS>
```

Copy the value of `sfdxAuthUrl` to the clipboard.

Create a GitHub Action Secret (`Settings > Secrets and variables > Actions > New repository secret`):

| Name                       | Secret                           |
| -------------------------- | -------------------------------- |
| `SFDX_AUTH_URL_TARGET_ORG` | `<PASTE_THE_SFDX_AUTH_URL_HERE>` |

## Step 3: Validate

- Create a PR and verify the Action was run successfully
- Merge the PR and verify the Action was run successfully

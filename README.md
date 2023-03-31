# Hutte Recipe - CI/CD Incremental Deployment

> This recipe uses [sfdx-git-delta](https://github.com/scolladon/sfdx-git-delta) to incrementally deploy changes.

> **Note** PRs need to be merged via "Create a merge commit" or "Squash and merge" option to correctly detect the changes.

## Prerequisites

- a GitHub repository with a valid sfdx project
- a target org authenticated with sfdx locally

## Steps

### Step 1

Create the following two GitHub Workflows:

`.github/workflows/incremental-validate.yml`

```yaml
# Based on https://github.com/mehdisfdc/sfdx-GitHub-actions/blob/main/.github/workflows/main.yml
name: Incremental validation deployment

on:
  pull_request:

jobs:
  default:
    runs-on: ubuntu-latest
    steps:
      - name: Install Salesforce CLI
        run: |
          npm install --global sfdx-cli
          sfdx --version
      - name: Install sfdx plugin
        run: |
          echo y | sfdx plugins:install sfdx-git-delta
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Authenticate target org
        run: |
          sfdx org login sfdx-url --set-default --sfdx-url-file <(echo "${{ secrets.SFDX_AUTH_URL_TARGET_ORG }}")
      - name: Validate deploying changes to target org
        run: |
          git merge "origin/${GITHUB_BASE_REF}"
          sfdx sgd:source:delta --from "origin/${GITHUB_BASE_REF}" --to "HEAD" --output "." --ignore .forceignore
          echo "# package.xml"
          cat package/package.xml; echo ""
          echo "# destructiveChanges.xml"
          cat destructiveChanges/destructiveChanges.xml; echo ""
          sfdx force:source:deploy --manifest package/package.xml --postdestructivechanges destructiveChanges/destructiveChanges.xml --wait 30 --testlevel RunLocalTests --checkonly
```

`.github/workflows/incremental-deploy.yml`

```yaml
# Based on https://github.com/mehdisfdc/sfdx-GitHub-actions/blob/main/.github/workflows/main.yml
name: Incremental deployment

on:
  push:
    branches:
      - main

jobs:
  default:
    runs-on: ubuntu-latest
    steps:
      - name: Install Salesforce CLI
        run: |
          npm install --global sfdx-cli
          sfdx --version
      - name: Install sfdx plugin
        run: |
          echo y | sfdx plugins:install sfdx-git-delta
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Authenticate target org
        run: |
          sfdx org login sfdx-url --set-default --sfdx-url-file <(echo "${{ secrets.SFDX_AUTH_URL_TARGET_ORG }}")
      - name: Deploy changes to target org
        # Note: This requires the merged PR to only have a single commit or merge commit
        run: |
          sfdx sgd:source:delta --from "HEAD~1" --to "HEAD" --output "." --ignore .forceignore
          echo "# package.xml"
          cat package/package.xml; echo ""
          echo "# destructiveChanges.xml"
          cat destructiveChanges/destructiveChanges.xml; echo ""
          sfdx force:source:deploy --manifest package/package.xml --postdestructivechanges destructiveChanges/destructiveChanges.xml --wait 30 --testlevel RunLocalTests
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

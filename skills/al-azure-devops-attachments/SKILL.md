---
name: al-azure-devops-attachments
description: Use when local files must be uploaded and attached to an Azure DevOps work item, or an attachment attempt is blocked by Azure CLI authentication.
---

# al-azure-devops-attachments - attach work-item files

In: an Azure DevOps work-item ID or URL and one or more local file paths. The Azure DevOps MCP edits work items; this skill owns file upload through Azure CLI credentials and the WIT attachments API.

Ask every question in the reply itself, as plain text — never through a question or elicitation tool. Never call the ask_user tool. Before the first tool call, write one sentence. Update only on an important finding or changed direction.

## Authenticate

Use the existing Azure CLI token cache. Read the organization and project from the work-item URL or `az devops configure --list`; never change those defaults. Request the Azure DevOps token for the target tenant:

`az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --tenant 3c2c919b-877a-4cd6-be64-b25bbdaee76f --query accessToken -o tsv --only-show-errors`

Keep the Azure CLI identity and defaults unchanged. Never run `az login` for the user, `az logout`, `az account set`, or `az devops configure -d`. When the token request reports an authentication failure, give the user this exact command:

`az login --tenant 3c2c919b-877a-4cd6-be64-b25bbdaee76f --scope "499b84ac-1321-427f-aa17-267ca6975798/.default" --allow-no-subscriptions`

Explain that Azure DevOps needs no Azure subscription. Stop until the user confirms authentication, then retry the token request. Authentication failure never becomes a manual-upload handoff.

## Upload and relate

Read the work item with `az boards work-item show --expand relations` before mutation. Normalize each relation type by removing spaces so the CLI name `Attached File` and the WIT name `AttachedFile` both match. For every matching attachment whose name matches an input filename, preserve its index for replacement.

Upload every file as binary with `Invoke-RestMethod -Method Post`, a Bearer token, `Content-Type: application/octet-stream`, and:

`https://dev.azure.com/<organization>/<project>/_apis/wit/attachments?fileName=<encoded-name>&api-version=7.1`

Require an attachment URL in every response. `az devops invoke --in-file` and `az rest --body @file` do not carry binary files reliably.

With no matching filename, add the returned URL with `az boards work-item relation add --relation-type 'Attached File' --target-url <url>`. With a match, use a WIT JSON Patch with `test /rev`, remove matching `/relations/<index>` paths in descending order, then add the new `AttachedFile` relation. On a revision conflict, read the work item again before retrying. Keep unrelated relations untouched.

## Verify and return

Read the work item again with `--expand relations` and apply the same relation-type normalization. Finish only when every requested filename appears exactly once as an attachment and its URL is the one returned by this upload.

Return the work-item ID, revision, and verified attachment names and URLs to the caller. Finish outcome first; on failure, name the exact command and error.

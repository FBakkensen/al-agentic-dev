#!/usr/bin/env bash
# Coordinator watch for one spec: bash watch-team.sh <spec-number>
# Every stdout line is an event for the lead. It watches every open PR that closes an open
# child of the spec, or that sits on a claude/team-* branch, re-reading the child list each loop.
# It emits:
#   - each state change;
#   - an actionable state again every REALERT seconds until it changes;
#   - a WATCH ERROR after 3 failed or empty queries in a row;
#   - each PR's final MERGED or CLOSED once.
# It exits when the spec has no open child.
# Env: REALERT (seconds, default 180), REVIEW_CHECK (the automatic review's check name, default claude-review).
spec=${1:?usage: watch-team.sh <spec-number>}
REALERT=${REALERT:-180}; REVIEW_CHECK=${REVIEW_CHECK:-claude-review}
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner) || { echo "WATCH ERROR: gh repo view failed"; exit 1; }
owner=${repo%/*}; name=${repo#*/}
declare -A last since done_ known child; errs=0

err() { errs=$((errs+1)); [ "$errs" -ge 3 ] && { echo "WATCH ERROR (x$errs): $1"; errs=0; }; }

while :; do
  now=$(date +%s)
  kids=$(gh api graphql -f query="query{repository(owner:\"$owner\",name:\"$name\"){issue(number:$spec){subIssues(first:100){totalCount nodes{number state}}}}}" \
    --jq '.data.repository.issue.subIssues | "\(.totalCount) " + ([.nodes[] | select(.state=="OPEN") | .number] | map(tostring) | join(","))' 2>&1)
  if [ $? -ne 0 ] || [ -z "$kids" ] || [ "${kids%% *}" = "0" ]; then err "spec #$spec sub-issues: $(echo "$kids" | head -c 160)"; sleep 30; continue; fi
  open=${kids#* }
  if [ -z "$open" ]; then echo "ALL CHILDREN OF #$spec CLOSED"; exit 0; fi

  raw=$(gh pr list --repo "$repo" --state open --limit 100 --json number,headRefName,closingIssuesReferences 2>&1)
  if [ $? -ne 0 ]; then err "gh pr list: $(echo "$raw" | head -c 160)"; sleep 30; continue; fi
  prs=$(jq -r --arg open ",$open," '.[] | select((.headRefName|startswith("claude/team-")) or ([.closingIssuesReferences[].number | tostring] | any(. as $n | $open | contains(","+$n+",")))) | "\(.number):\([.closingIssuesReferences[].number] | map(tostring) | join("+"))"' <<<"$raw")
  errs=0
  for entry in $prs; do pr=${entry%%:*}; [ -z "${known[$pr]}" ] && { known[$pr]=1; echo "NEW PR #$pr closes #${entry#*:}"; }; child[$pr]=${entry#*:}; done

  for pr in "${!known[@]}"; do
    [ -n "${done_[$pr]}" ] && continue
    j=$(gh pr view "$pr" --repo "$repo" --json state,mergeStateStatus,statusCheckRollup 2>&1) || { err "gh pr view #$pr: $(echo "$j" | head -c 160)"; continue; }
    st=$(jq -r '.state+" "+.mergeStateStatus' <<<"$j")
    failed=$(jq -r '[.statusCheckRollup[]? | select((.conclusion // "") | test("FAILURE|CANCELLED|TIMED_OUT|ACTION_REQUIRED|ERROR")) | (.name // .context)] | join(",")' <<<"$j")
    review=$(jq -r --arg c "$REVIEW_CHECK" '[.statusCheckRollup[]? | select((.name // .context) == $c) | (.conclusion // .status // "pending")] | first // "absent" | ascii_downcase' <<<"$j")
    th=$(gh api graphql -f query="query{repository(owner:\"$owner\",name:\"$name\"){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved comments(first:1){nodes{body}}}}}}}" \
      --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved|not)] | "\(length) \([.[] | select(.comments.nodes[0].body|startswith("HOLD (team-lead)"))] | length)"' 2>/dev/null) || th="? ?"
    threads=${th% *}; hold=${th#* }
    cur="$st threads=$threads hold=$hold review=$review${failed:+ FAILED-CHECKS=$failed}"
    tag="PR #$pr (#${child[$pr]:-?})"
    case "$st" in MERGED*|CLOSED*) echo "$tag: $cur (final)"; done_[$pr]=1; continue;; esac
    if [ "$cur" != "${last[$pr]}" ]; then echo "$tag: $cur"; last[$pr]=$cur; since[$pr]=$now; continue; fi
    act=0
    case "$st" in *DIRTY*|*UNSTABLE*) act=1;; *CLEAN*) [ "$hold" = "0" ] && act=1;; esac
    [ -n "$failed" ] && act=1
    [ "$threads" != "?" ] && [ "$threads" -gt "$hold" ] 2>/dev/null && act=1
    if [ "$act" = 1 ] && [ $((now - ${since[$pr]})) -ge "$REALERT" ]; then
      echo "STILL ACTIONABLE $tag for $(( (now - ${since[$pr]}) / 60 ))m: $cur"; since[$pr]=$now
    fi
  done
  sleep 30
done

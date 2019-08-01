##
## This code runs on Jenkins' machine using its environment variables to get Gerrit data.
## Its functionality is to get a patch from Gerrit and make comments on Gitlab's related issue.
## For now, the code only posts on Gitlab the URL of Gerrit's patch.
##

import re
import requests
import os
import json
from requests.auth import HTTPBasicAuth
from urllib.parse import quote


def get_issue(project, issue_id):
    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/{}".format(
                 quote(project, safe=""), issue_id)
    try:
        return requests.get(gitlab_url,
                            headers={"Private-Token": os.getenv("GITLAB_API_TOKEN")}).json()
    except ValueError:
        return None


def swap_labels_of_issue(project, issue_id, remove_label, append_label):
    issue = get_issue(project, issue_id)
    if not issue:
        return

    labels = issue.get('labels')
    if remove_label not in labels:
        return

    labels.remove(remove_label)
    labels.append(append_label)

    # Gitlab's API doesn't accept an array of strings, only a comma separated string
    labels_str = ','.join(labels)
    return update_issue(project, issue_id, {"labels": labels_str})


def update_issue(project, issue_id, params):
    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/{}".format(
                 quote(project, safe=""), issue_id)
    return requests.put(gitlab_url, headers={"Private-Token": os.getenv("GITLAB_API_TOKEN")},
                        params=params)


def comment_on_issue(project, issue_id, data):
    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/{}/notes".format(
                 quote(project, safe=""), issue_id)
    return requests.post(gitlab_url, headers={"Private-Token": os.getenv("GITLAB_API_TOKEN")},
                         data=data)


def get_gerrit_data(url):
    gerrit_data = requests.get(url, auth=HTTPBasicAuth(os.getenv("GERRIT_USER"),
                                                       os.getenv("GERRIT_PASS")))
    # According to the Gerrit's API, the response contains 4 characters at the beginning: )]}'
    # https://gerrit-review.googlesource.com/Documentation/rest-api-changes.html#get-change-detail
    # They need to be removed before parsing json
    try:
        return json.loads(gerrit_data.text[5:])
    except ValueError:
        return None


def main():
    # Get info from commit message of Gerrit
    project, issue_id = re.search("Fixes: https://gitlab.com/(.*)/issues/(\d+)",
                                  os.getenv("GERRIT_CHANGE_COMMIT_MESSAGE")).groups()
    assert project and issue_id, (project, issue_id)

    # Add the comment to gitlab for the first patchset
    if int(os.getenv("GERRIT_PATCHSET_NUMBER")) == 1:
        data = {"body": os.getenv("GERRIT_CHANGE_URL")}
        comment_on_issue(project, issue_id, data)
        return

    # Check if the patch is WIP
    re_wip = re.compile(r'\bwip\b', re.IGNORECASE)
    if re_wip.search(os.getenv("GERRIT_CHANGE_SUBJECT")) is not None:
        return

    # Swap labels of the issue
    if swap_labels_of_issue(project, issue_id, 'status: Doing', 'status: Review') is not None:
        return

    # Get reviews of the patch from Gerrit
    gerrit_patch_id = "{}~{}~{}".format(os.getenv("GERRIT_PROJECT"), os.getenv("GERRIT_BRANCH"),
                                        os.getenv("GERRIT_CHANGE_ID"))
    gerrit_detail_url = "https://gerrit.async.com.br/a/changes/{}/detail".format(gerrit_patch_id)
    patch_data = get_gerrit_data(gerrit_detail_url)
    if not patch_data:
        return

    gerrit_reviews = patch_data['labels']['Code-Review']['all']

    # Populate code review values
    # The review values from older patch sets will be shown as 0. So only the current patch set
    # will be valid for the following activities
    code_review_values = list(map(lambda item: item.get('value', 0), gerrit_reviews))

    # Modify issues based on code review
    if ((-1 or -2) in code_review_values):
        # Patch has required modifications
        swap_labels_of_issue(project, issue_id, 'status: Review', 'status: To Do')
    elif any(v == 2 for v in code_review_values):
        # Patch was merged
        update_issue(project, issue_id, {"state_event": "close"})


if __name__ == '__main__':
    main()

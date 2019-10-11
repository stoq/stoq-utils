##
## This code is called from every pipeline on Gitlab to validate the commit message content.
## It will assert an error if any of the requirements have not been met.
##

import os
import sys
import re
import requests
from urllib.parse import quote


def main(commit_message):
    issue_link = extract_issue_path(commit_message)
    assert issue_link, "The action keyword is missing or wrong, or a path wasn't provided."

    # Make sure the path points to an issue
    contain_issue = 'issues' in issue_link
    assert contain_issue, "The given path isn't an issue link."

    # Grab info from the related issue and check if it has not been closed yet
    project, issue_id = re.search("(.*)/issues/(\d+)", issue_link).groups()
    issue = get_issue(project, issue_id)
    issue_is_open = issue.get('state', '').lower() == 'opened'
    assert issue_is_open, "Issue already closed."


def extract_issue_path(commit_message):
    # Find the related link in the commit message's body
    # It must be preceded by Close, Fix, Resolve or Implement
    issue_pattern = "https://gitlab.com/(.*)"
    rule = re.compile(r'(Clos(e|es|ed|ing)|Fi(x|xes|xed|xing)|Resolv(e|es|ed|ing)|'
                      'Implemen(t|ts|ted|ting)|Related to)\:[ ]{0}'.format(issue_pattern), re.I)
    result = re.search(rule, commit_message)
    if result:
        return result.groups()[-1]


def get_issue(project, issue_id):
    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/{}".format(
                 quote(project, safe=""), issue_id)

    response = requests.get(gitlab_url,
                            headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")})

    if not response.ok:
        return None

    return response.json()


if __name__ == '__main__':
    main(sys.argv[1])

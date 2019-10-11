from unittest import mock

import pytest

from gitlab_commit_validator import extract_issue_path, get_issue, main
from .vcr import vcr


def test_extract_issue_path_invalid_commit_message():
    commit_message = 'This is a commit message'
    assert extract_issue_path(commit_message) is None


@pytest.mark.parametrize('prefix', ('implements', 'fixes', 'resolves', 'closes', 'related to'))
@pytest.mark.parametrize('path, expected_result', (
    ('https://gitlab.com/', ''),
    ('https://gitlab.com/issues', 'issues'),
    ('https://gitlab.com/stoqtech/squads/kazoo/tasks/issues/4',
     'stoqtech/squads/kazoo/tasks/issues/4'),
))
def test_extract_issue_path(prefix, path, expected_result):
    commit_message = 'Random commit message {}: {}'.format(prefix, path)
    assert extract_issue_path(commit_message) == expected_result


@vcr.use_cassette
def test_get_issue_invalid_project():
    assert get_issue('project', '0') is None


@vcr.use_cassette
def test_get_issue():
    project = 'stoqtech/squads/kazoo/tasks'
    issue_id = '4'
    issue = get_issue(project, issue_id)
    assert issue['iid'] == 4
    assert issue['state'] == 'opened'


@mock.patch('gitlab_commit_validator.get_issue')
def test_main(mock_get_issue):
    mock_get_issue.return_value = {'state': 'opened'}
    commit_message = """
    Create script to check Fixes of commit messages
    When a commit is sent to Gitlab, the pipeline will run tests on it.
    This patch includes a verification if there is a Fixes link in the commit message and it isn't
    pointing to a merge request.
    Fixes: https://gitlab.com/stoqtech/squads/kazoo/tasks/issues/4
    Change-Id: I0c638ee30025d8cc81c53e087af721325eca3768 """
    assert main(commit_message) is None


@mock.patch('gitlab_commit_validator.get_issue')
@pytest.mark.parametrize('commit_message, expected_result', (
    ("This is a commit message",
     "The action keyword is missing or wrong, or a path wasn't provided."),
    ("Fixes: https://gitlab.com/stoqtech/squads/kazoo/", "The given path isn't an issue link."),
    ("Fixes: https://gitlab.com/stoqtech/squads/kazoo/tasks/issues/4", "Issue already closed."),
))
def test_main_invalid_parameters(mock_get_issue, commit_message, expected_result):
    mock_get_issue.return_value = {"state": "closed"}
    with pytest.raises(AssertionError) as context:
        main(commit_message)

    assert(expected_result in str(context.value))

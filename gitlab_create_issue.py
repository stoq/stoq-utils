import requests
import os
import inquirer
import pyperclip
import sys
from prompt_toolkit import prompt


def get_members(group_project):
    print('\nGetting members...')
    members_url = "https://gitlab.com/api/v4/projects/{}/members/all".format(group_project)
    members = requests.get(members_url,
                           headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")}).json()

    filtered_members = []
    for member in members:
        if member not in filtered_members:
            filtered_members.append(member)

    return filtered_members


def main():
    '''
    Create Gitlab issues from terminal.
    Gitlab access token is required and a environment var must be exported:
    export GL_ACCESS_TOKEN='YOUR_GITLAB_ACCESS_TOKEN_HERE'

    To commit to BdiL project directly, export the following environment vars:
    export GL_SKIP_REPO_TYPES='True'
    export GL_GROUP='stoqtech'
    export GL_PROJECT='private/bdil'
    '''

    access_token = os.getenv("GL_ACCESS_TOKEN")
    assert access_token, access_token

    if os.getenv("GL_SKIP_REPO_TYPES"):
        repo_type = 'group'
    else:
        repo_types = ['personal', 'group']
        questions = [inquirer.List('repo type', message="Repository type", choices=repo_types)]
        repo_type = list(inquirer.prompt(questions).values())[0]

    # Group or user
    if repo_type == 'group':
        group = os.getenv("GL_GROUP")
        if group is None:
            print("What's the group?")
            group = ''
            while group == '':
                group = prompt('>')
    else:
        user = os.getenv("GL_USER")
        if user is None:
            print("What's the user?")
            user = ''
            while user == '':
                user = prompt('>')

    # Project
    project = os.getenv("GL_PROJECT")
    if project is None:
        print("What's the project? (If it's private, start with private/")
        project = ''
        while project == '':
            project = prompt('>')

    repo_formatted = ''
    if repo_type == 'group':
        repo_formatted = (group + '/' + project).replace('/', '%2F')
    else:
        repo_formatted = (user + '/' + project).replace('/', '%2F')

    # Labels
    print('Getting labels...')
    if repo_type == 'group':
        labels_url = "https://gitlab.com/api/v4/groups/{}/labels/".format(group)
    else:
        labels_url = "https://gitlab.com/api/v4/projects/{}/labels/".format(repo_formatted)
    params = dict(per_page='100')
    result = requests.get(labels_url, headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")},
                          params=params)
    labels_list = []
    for label in result.json():
        labels_list.append(label['name'])

    # Members
    members = get_members(repo_formatted)
    members_name = []
    for member in members:
        members_name.append(member['name'])

    print("\nWhat's the title?")
    title = ''
    while title == '':
        title = prompt('>')

    print("\nWhat's the description?")
    description = ''
    while description == '':
        description = prompt('>')

    print("\nWho is the assignee?")
    questions = [inquirer.List('members', message="Selected assignee", choices=members_name)]
    assignee = list(inquirer.prompt(questions).values())[0]
    user_id = ''
    for member in members:
        if member['name'] == assignee:
            user_id = member['id']
            break

    print("\nWhich labels should it contain? (Press space to select)")
    questions = [
        inquirer.Checkbox('labels', message="Selected labels", choices=labels_list)]
    labels = inquirer.prompt(questions)
    labels_value = ''
    for val in list(labels.values())[0]:
        labels_value += val + ','

    params = dict(
        title=title,
        description=description,
        labels=labels_value,
        assignee_ids=[user_id],
    )

    gitlab_url = "https://gitlab.com/api/v4/projects/{}/issues/".format(repo_formatted)
    new_issue = requests.post(gitlab_url, headers={"Private-Token": os.getenv("GL_ACCESS_TOKEN")},
                              params=params)
    web_url = new_issue.json()['web_url']
    pyperclip.copy(web_url)
    print(web_url)


if __name__ == '__main__':
    if len(sys.argv) > 1 and '-h' in sys.argv[1]:
        help(main)
    else:
        main()

#!/usr/bin/env python3
"""Tests for json-helper.py"""

import json
import os
import subprocess
import unittest

SCRIPT = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'json-helper.py')


def run_helper(action, args=None, stdin_data=None):
    cmd = ['python3', SCRIPT, action] + (args or [])
    result = subprocess.run(cmd, input=stdin_data, capture_output=True, text=True)
    return result


class TestBodyPayload(unittest.TestCase):
    def test_simple(self):
        r = run_helper('body-payload', stdin_data='hello world')
        self.assertEqual(json.loads(r.stdout), {'body': 'hello world'})

    def test_multiline(self):
        r = run_helper('body-payload', stdin_data='line1\nline2\nline3')
        data = json.loads(r.stdout)
        self.assertIn('\n', data['body'])

    def test_empty(self):
        r = run_helper('body-payload', stdin_data='')
        self.assertEqual(json.loads(r.stdout), {'body': ''})

    def test_special_chars(self):
        r = run_helper('body-payload', stdin_data='{"key": "value"}')
        data = json.loads(r.stdout)
        self.assertEqual(data['body'], '{"key": "value"}')


class TestCount(unittest.TestCase):
    def test_empty_array(self):
        r = run_helper('count', stdin_data='[]')
        self.assertEqual(r.stdout.strip(), '0')

    def test_array(self):
        r = run_helper('count', stdin_data='[1,2,3]')
        self.assertEqual(r.stdout.strip(), '3')

    def test_non_array(self):
        r = run_helper('count', stdin_data='{"a":1}')
        self.assertEqual(r.stdout.strip(), '0')

    def test_invalid_json(self):
        r = run_helper('count', stdin_data='not json')
        self.assertEqual(r.stdout.strip(), '0')

    def test_large_array(self):
        data = json.dumps(list(range(100)))
        r = run_helper('count', stdin_data=data)
        self.assertEqual(r.stdout.strip(), '100')


class TestUrlEncode(unittest.TestCase):
    def test_ascii(self):
        r = run_helper('url-encode', ['hello/world'])
        self.assertEqual(r.stdout.strip(), 'hello%2Fworld')

    def test_chinese(self):
        r = run_helper('url-encode', ['中文'])
        self.assertNotEqual(r.stdout.strip(), '中文')
        self.assertIn('%', r.stdout.strip())

    def test_special_chars(self):
        r = run_helper('url-encode', ['a b@c'])
        self.assertIn('%20', r.stdout.strip())
        self.assertIn('%40', r.stdout.strip())

    def test_empty(self):
        r = run_helper('url-encode', [''])
        self.assertEqual(r.stdout.strip(), '')

    def test_missing_arg(self):
        r = run_helper('url-encode')
        self.assertEqual(r.returncode, 4)


class TestParseUrl(unittest.TestCase):
    def test_issue_url(self):
        r = run_helper('parse-url', ['issue', 'http://gitlab.example.com/mygroup/myproject/-/issues/8', 'http://gitlab.example.com'])
        data = json.loads(r.stdout)
        self.assertEqual(data['project_path'], 'mygroup/myproject')
        self.assertEqual(data['issue_iid'], 8)

    def test_issue_url_subgroup(self):
        r = run_helper('parse-url', ['issue', 'http://gitlab.example.com/a/b/c/-/issues/42', 'http://gitlab.example.com'])
        data = json.loads(r.stdout)
        self.assertEqual(data['project_path'], 'a/b/c')
        self.assertEqual(data['issue_iid'], 42)

    def test_issue_url_host_mismatch(self):
        r = run_helper('parse-url', ['issue', 'http://other.com/mygroup/myproject/-/issues/1', 'http://gitlab.example.com'])
        self.assertNotEqual(r.returncode, 0)
        data = json.loads(r.stdout)
        self.assertIn('error', data)

    def test_issue_url_invalid(self):
        r = run_helper('parse-url', ['issue', 'http://gitlab.example.com/mygroup/myproject', 'http://gitlab.example.com'])
        self.assertNotEqual(r.returncode, 0)

    def test_mr_url(self):
        r = run_helper('parse-url', ['mr', 'http://gitlab.example.com/mygroup/myproject/-/merge_requests/5', 'http://gitlab.example.com'])
        data = json.loads(r.stdout)
        self.assertEqual(data['project_path'], 'mygroup/myproject')
        self.assertEqual(data['mr_iid'], 5)

    def test_mr_url_host_mismatch(self):
        r = run_helper('parse-url', ['mr', 'http://other.com/mygroup/myproject/-/merge_requests/5', 'http://gitlab.example.com'])
        self.assertNotEqual(r.returncode, 0)

    def test_project_url(self):
        r = run_helper('parse-url', ['project', 'http://gitlab.example.com/mygroup/myproject'])
        data = json.loads(r.stdout)
        self.assertEqual(data['project_path'], 'mygroup/myproject')

    def test_project_url_with_git_suffix(self):
        r = run_helper('parse-url', ['project', 'http://gitlab.example.com/mygroup/myproject.git'])
        data = json.loads(r.stdout)
        self.assertEqual(data['project_path'], 'mygroup/myproject')

    def test_project_url_rejects_issue(self):
        r = run_helper('parse-url', ['project', 'http://gitlab.example.com/mygroup/myproject/-/issues/8'])
        self.assertNotEqual(r.returncode, 0)

    def test_project_url_rejects_mr(self):
        r = run_helper('parse-url', ['project', 'http://gitlab.example.com/mygroup/myproject/-/merge_requests/5'])
        self.assertNotEqual(r.returncode, 0)

    def test_project_url_strips_suffix(self):
        r = run_helper('parse-url', ['project', 'http://gitlab.example.com/mygroup/myproject/-/boards'])
        data = json.loads(r.stdout)
        self.assertEqual(data['project_path'], 'mygroup/myproject')

    def test_unknown_type(self):
        r = run_helper('parse-url', ['unknown', 'http://example.com'])
        self.assertEqual(r.returncode, 4)


class TestIssuePayload(unittest.TestCase):
    def test_with_labels(self):
        r = run_helper('issue-payload', ['My Title', 'bug,feature'], stdin_data='desc text')
        data = json.loads(r.stdout)
        self.assertEqual(data['title'], 'My Title')
        self.assertEqual(data['description'], 'desc text')
        self.assertEqual(data['labels'], 'bug,feature')

    def test_without_labels(self):
        r = run_helper('issue-payload', ['Title', ''], stdin_data='desc')
        data = json.loads(r.stdout)
        self.assertEqual(data['title'], 'Title')
        self.assertNotIn('labels', data)

    def test_multiline_desc(self):
        r = run_helper('issue-payload', ['T'], stdin_data='line1\nline2')
        data = json.loads(r.stdout)
        self.assertIn('\n', data['description'])


class TestLabelsPayload(unittest.TestCase):
    def test_add_only(self):
        r = run_helper('labels-payload', ['workflow::start'])
        data = json.loads(r.stdout)
        self.assertEqual(data['add_labels'], 'workflow::start')
        self.assertNotIn('remove_labels', data)

    def test_add_and_remove(self):
        r = run_helper('labels-payload', ['workflow::start', 'workflow::backlog'])
        data = json.loads(r.stdout)
        self.assertEqual(data['add_labels'], 'workflow::start')
        self.assertEqual(data['remove_labels'], 'workflow::backlog')


class TestDescriptionPayload(unittest.TestCase):
    def test_basic(self):
        r = run_helper('description-payload', stdin_data='new desc')
        data = json.loads(r.stdout)
        self.assertEqual(data['description'], 'new desc')


class TestMrPayload(unittest.TestCase):
    def test_full(self):
        r = run_helper('mr-payload', ['dev-alice-8', 'dev', 'Resolve "title"', 'true', 'true'], stdin_data='MR desc')
        data = json.loads(r.stdout)
        self.assertEqual(data['source_branch'], 'dev-alice-8')
        self.assertEqual(data['target_branch'], 'dev')
        self.assertEqual(data['title'], 'Resolve "title"')
        self.assertEqual(data['description'], 'MR desc')
        self.assertTrue(data['remove_source_branch'])
        self.assertTrue(data['squash'])

    def test_false_booleans(self):
        r = run_helper('mr-payload', ['src', 'tgt', 'title', 'false', 'false'], stdin_data='')
        data = json.loads(r.stdout)
        self.assertFalse(data['remove_source_branch'])
        self.assertFalse(data['squash'])


class TestIdsPayload(unittest.TestCase):
    def test_reviewer_ids(self):
        r = run_helper('ids-payload', ['reviewer_ids', '22,33'])
        data = json.loads(r.stdout)
        self.assertEqual(data['reviewer_ids'], [22, 33])

    def test_assignee_ids(self):
        r = run_helper('ids-payload', ['assignee_ids', '5'])
        data = json.loads(r.stdout)
        self.assertEqual(data['assignee_ids'], [5])

    def test_empty(self):
        r = run_helper('ids-payload', ['assignee_ids', ''])
        data = json.loads(r.stdout)
        self.assertEqual(data['assignee_ids'], [])

    def test_invalid(self):
        r = run_helper('ids-payload', ['reviewer_ids', 'abc'])
        self.assertNotEqual(r.returncode, 0)


class TestMergeArrays(unittest.TestCase):
    def test_single_page(self):
        r = run_helper('merge-arrays', stdin_data='[1,2,3]\n')
        data = json.loads(r.stdout)
        self.assertEqual(data, [1, 2, 3])

    def test_multi_page(self):
        r = run_helper('merge-arrays', stdin_data='[1,2]\n[3,4]\n')
        data = json.loads(r.stdout)
        self.assertEqual(data, [1, 2, 3, 4])

    def test_empty(self):
        r = run_helper('merge-arrays', stdin_data='')
        data = json.loads(r.stdout)
        self.assertEqual(data, [])

    def test_invalid_line(self):
        r = run_helper('merge-arrays', stdin_data='[1]\nnot json\n[2]\n')
        data = json.loads(r.stdout)
        self.assertEqual(data, [1, 2])


class TestResolveProject(unittest.TestCase):
    def test_valid(self):
        inp = json.dumps({'id': 42, 'name': 'test', 'path_with_namespace': 'mygroup/myproject'})
        r = run_helper('resolve-project', stdin_data=inp)
        data = json.loads(r.stdout)
        self.assertEqual(data['project_id'], 42)
        self.assertEqual(data['name'], 'test')

    def test_missing_field(self):
        r = run_helper('resolve-project', stdin_data='{"id": 1}')
        self.assertNotEqual(r.returncode, 0)

    def test_invalid_json(self):
        r = run_helper('resolve-project', stdin_data='not json')
        self.assertNotEqual(r.returncode, 0)


class TestFindMember(unittest.TestCase):
    def test_found(self):
        members = json.dumps([
            {'id': 10, 'username': 'alice', 'name': 'Alice'},
            {'id': 20, 'username': 'bob', 'name': 'Bob'}
        ])
        r = run_helper('find-member', ['alice'], stdin_data=members)
        data = json.loads(r.stdout)
        self.assertEqual(data['user_id'], 10)

    def test_not_found(self):
        members = json.dumps([{'id': 10, 'username': 'alice', 'name': 'Alice'}])
        r = run_helper('find-member', ['charlie'], stdin_data=members)
        self.assertNotEqual(r.returncode, 0)

    def test_empty_list(self):
        r = run_helper('find-member', ['alice'], stdin_data='[]')
        self.assertNotEqual(r.returncode, 0)


class TestRenderMrTemplate(unittest.TestCase):
    TEMPLATE_FILE = os.path.join(os.path.dirname(__file__), '..', 'templates', 'mr-description-template.md')

    def test_basic_render(self):
        r = run_helper('render-mr-template', [self.TEMPLATE_FILE, '8', 'Test Title'])
        self.assertEqual(r.returncode, 0)
        self.assertIn('Closes #8', r.stdout)
        self.assertTrue('（待填写）' in r.stdout or '(to be filled)' in r.stdout)

    def test_with_description_file(self):
        import tempfile
        with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
            f.write('Added login feature\n')
            desc_file = f.name
        try:
            r = run_helper('render-mr-template', [self.TEMPLATE_FILE, '12', 'Login', desc_file])
            self.assertEqual(r.returncode, 0)
            self.assertIn('Closes #12', r.stdout)
            self.assertIn('Added login feature', r.stdout)
            self.assertNotIn('（待填写）', r.stdout)
        finally:
            os.unlink(desc_file)

    def test_missing_template(self):
        r = run_helper('render-mr-template', ['/nonexistent/template.md', '1', 'Title'])
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout.strip(), '')

    def test_missing_description_file(self):
        r = run_helper('render-mr-template', [self.TEMPLATE_FILE, '5', 'Title', '/nonexistent/desc.md'])
        self.assertEqual(r.returncode, 0)
        self.assertTrue('（待填写）' in r.stdout or '(to be filled)' in r.stdout)

    def test_missing_args(self):
        r = run_helper('render-mr-template', [self.TEMPLATE_FILE])
        self.assertNotEqual(r.returncode, 0)


class TestGetField(unittest.TestCase):
    def test_string_field(self):
        r = run_helper('get-field', ['username'], stdin_data='{"user_id": 42, "username": "alice"}')
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, 'alice')

    def test_int_field(self):
        r = run_helper('get-field', ['user_id'], stdin_data='{"user_id": 42, "username": "alice"}')
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '42')

    def test_missing_field(self):
        r = run_helper('get-field', ['nonexistent'], stdin_data='{"user_id": 42}')
        self.assertEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '')

    def test_invalid_json(self):
        r = run_helper('get-field', ['user_id'], stdin_data='not json')
        self.assertNotEqual(r.returncode, 0)

    def test_no_args(self):
        r = run_helper('get-field', stdin_data='{}')
        self.assertNotEqual(r.returncode, 0)


class TestUnknownAction(unittest.TestCase):
    def test_unknown(self):
        r = run_helper('nonexistent')
        self.assertEqual(r.returncode, 1)


if __name__ == '__main__':
    unittest.main()

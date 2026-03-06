#!/usr/bin/env python3
"""Tests for issue-parser.sh (testing the embedded Python logic)"""

import json
import os
import subprocess
import unittest

PARSER_SCRIPT = os.path.join(os.path.dirname(__file__), '..', 'scripts', 'issue-parser.sh')
FIXTURES_DIR = os.path.join(os.path.dirname(__file__), 'fixtures')


def parse_file(fixture_name):
    filepath = os.path.join(FIXTURES_DIR, fixture_name)
    result = subprocess.run(
        ['bash', PARSER_SCRIPT, filepath],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def parse_text(text):
    result = subprocess.run(
        ['bash', PARSER_SCRIPT],
        input=text, capture_output=True, text=True
    )
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


class TestSectionParsing(unittest.TestCase):
    def test_full_issue(self):
        data = parse_file('sample-issue.md')
        self.assertIsNotNone(data)
        self.assertIn('background', data)
        self.assertIn('requirements', data)
        self.assertIn('acceptance_criteria', data)
        self.assertIn('technical_notes', data)
        self.assertIn('test_plan', data)
        self.assertIn('reviewer', data)
        self.assertIn('questions', data)

    def test_minimal_issue(self):
        data = parse_file('minimal-issue.md')
        self.assertIn('background', data)
        self.assertIn('requirements', data)
        self.assertIn('acceptance_criteria', data)
        self.assertTrue(data['_completeness']['has_all_required'])

    def test_section_mapping(self):
        text = '## Background\n\nSome background.\n\n## Requirements\n\n1. Item\n\n## Acceptance Criteria\n\n- [ ] Done'
        data = parse_text(text)
        self.assertIn('background', data)
        self.assertIn('requirements', data)
        self.assertIn('acceptance_criteria', data)


class TestCodeBlockHandling(unittest.TestCase):
    def test_code_block_headers_ignored(self):
        data = parse_file('code-block-issue.md')
        self.assertIn('background', data)
        self.assertIn('requirements', data)
        self.assertIn('acceptance_criteria', data)
        # Code block ## should not create extra sections
        self.assertNotIn('这不是章节标题', data)
        self.assertNotIn('这是代码块内的注释，不是章节', data)


class TestTodoExtraction(unittest.TestCase):
    def test_todos_extracted(self):
        text = '## 背景\n\nContext here.\n<!-- TODO: 需要确认接口 -->\n\n## 需求\n\n1. Item\n\n## 验收标准\n\n- [ ] Done'
        data = parse_text(text)
        self.assertIn('todos', data)
        self.assertEqual(len(data['todos']), 1)
        self.assertEqual(data['todos'][0]['content'], '需要确认接口')

    def test_todo_in_code_block_not_extracted(self):
        text = '## 背景\n\n```\n<!-- TODO: should ignore -->\n```\n\n## 需求\n\n1. Item\n\n## 验收标准\n\n- [ ] Done'
        data = parse_text(text)
        self.assertNotIn('todos', data)


class TestReviewerParsing(unittest.TestCase):
    def test_reviewer_formats(self):
        data = parse_file('reviewer-formats.md')
        self.assertIn('reviewer_list', data)
        self.assertIn('alice', data['reviewer_list'])
        self.assertIn('bob', data['reviewer_list'])
        self.assertIn('charlie', data['reviewer_list'])

    def test_reviewer_with_at(self):
        text = '## Reviewer\n\n@user1, @user2'
        data = parse_text(text)
        self.assertIn('reviewer_list', data)
        self.assertEqual(data['reviewer_list'], ['user1', 'user2'])

    def test_reviewer_without_at(self):
        text = '## Reviewer\n\nuser1, user2'
        data = parse_text(text)
        self.assertIn('reviewer_list', data)
        self.assertEqual(data['reviewer_list'], ['user1', 'user2'])

    def test_html_comment_not_parsed(self):
        text = '## Reviewer\n\n<!-- 指定 reviewer -->\nalice'
        data = parse_text(text)
        self.assertIn('reviewer_list', data)
        self.assertEqual(data['reviewer_list'], ['alice'])
        # Comment content should not appear
        self.assertNotIn('指定', str(data['reviewer_list']))


class TestRelatedIssues(unittest.TestCase):
    def test_related_issues(self):
        data = parse_file('sample-issue.md')
        self.assertIn('related_issues_list', data)
        self.assertEqual(len(data['related_issues_list']), 1)
        self.assertIn('url', data['related_issues_list'][0])

    def test_related_with_description(self):
        text = '## 关联 Issue\n\n- http://gitlab.example.com/mygroup/myproject/-/issues/5 — 说明文字'
        data = parse_text(text)
        self.assertIn('related_issues_list', data)
        self.assertEqual(data['related_issues_list'][0]['description'], '说明文字')


class TestCompleteness(unittest.TestCase):
    def test_complete(self):
        data = parse_file('sample-issue.md')
        self.assertTrue(data['_completeness']['has_all_required'])
        self.assertEqual(data['_completeness']['missing_sections'], [])

    def test_incomplete(self):
        data = parse_file('incomplete-issue.md')
        self.assertFalse(data['_completeness']['has_all_required'])
        self.assertIn('requirements', data['_completeness']['missing_sections'])
        self.assertIn('acceptance_criteria', data['_completeness']['missing_sections'])

    def test_empty_issue(self):
        data = parse_file('empty-issue.md')
        self.assertFalse(data['_completeness']['has_all_required'])

    def test_blank_section_treated_as_missing(self):
        text = '## 背景\n\n   \n\n## 需求\n\n1. Item\n\n## 验收标准\n\n- [ ] Done'
        data = parse_text(text)
        self.assertIn('background', data['_completeness']['missing_sections'])


if __name__ == '__main__':
    unittest.main()

#!/usr/bin/env python3
"""SDD Workflow — JSON Helper Tool

Usage:
  python3 json-helper.py body-payload          # stdin → {"body": "<content>"}
  python3 json-helper.py count                 # stdin JSON array → array length
  python3 json-helper.py url-encode <string>   # URL encode
  python3 json-helper.py parse-url <type> <url> [gitlab_url]  # Parse issue/mr/project URL
  python3 json-helper.py resolve-project       # stdin JSON → project id/name/path
  python3 json-helper.py find-member <username> # stdin JSON members → find user
  python3 json-helper.py issue-payload <title> [labels]  # stdin desc → issue JSON
  python3 json-helper.py labels-payload <add> [remove]   # → labels JSON
  python3 json-helper.py description-payload   # stdin desc → {"description": "..."}
  python3 json-helper.py mr-payload <src> <tgt> <title> <rm> <squash>  # stdin desc → MR JSON
  python3 json-helper.py ids-payload <field> <ids>  # → {"field": [ids]}
  python3 json-helper.py merge-arrays          # stdin JSON lines → merged array
  python3 json-helper.py render-mr-template <tpl> <iid> <title> [desc_file]  # Render MR template
  python3 json-helper.py get-field <field>     # stdin JSON object → field value
"""

import json
import os
import re
import sys
from urllib.parse import quote, urlparse


def _extract_project_data(data):
    """从 GitLab API 项目响应中提取核心字段"""
    return {
        'project_id': data['id'],
        'name': data['name'],
        'path_with_namespace': data['path_with_namespace']
    }


def _msg(zh, en):
    """Return message based on LANG environment variable."""
    _lang = os.environ.get('LANG', '')
    if _lang.startswith('zh_CN') or _lang.startswith('zh_TW'):
        return zh
    return en


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else ''

    if action == 'body-payload':
        body = sys.stdin.read()
        print(json.dumps({'body': body}))

    elif action == 'count':
        try:
            data = json.load(sys.stdin)
            print(len(data) if isinstance(data, list) else 0)
        except (json.JSONDecodeError, ValueError):
            print(0)

    elif action == 'url-encode':
        if len(sys.argv) < 3:
            print(_msg('用法: json-helper.py url-encode <string>', 'Usage: json-helper.py url-encode <string>'), file=sys.stderr)
            sys.exit(4)
        print(quote(sys.argv[2], safe=''))

    elif action == 'parse-url':
        if len(sys.argv) < 4:
            print(_msg('用法: json-helper.py parse-url <type> <url> [gitlab_url]', 'Usage: json-helper.py parse-url <type> <url> [gitlab_url]'), file=sys.stderr)
            sys.exit(4)
        url_type = sys.argv[2]
        url = sys.argv[3]
        gitlab_url = sys.argv[4] if len(sys.argv) > 4 else ''

        if url_type == 'issue':
            # Host validation
            if gitlab_url:
                url_host = urlparse(url).hostname or ''
                gitlab_host = urlparse(gitlab_url).hostname or ''
                if gitlab_host and url_host and url_host != gitlab_host:
                    print(json.dumps({'error': _msg(f'URL 主机名 {url_host} 与 GITLAB_URL {gitlab_host} 不匹配', f'URL hostname {url_host} does not match GITLAB_URL {gitlab_host}')}))
                    sys.exit(1)
            m = re.match(r'https?://[^/]+/(.+?)/-/issues/(\d+)', url)
            if m:
                print(json.dumps({'project_path': m.group(1), 'issue_iid': int(m.group(2))}))
            else:
                print(json.dumps({'error': _msg('URL 格式不匹配，期望：https://<host>/<project_path>/-/issues/<iid>', 'URL format mismatch, expected: https://<host>/<project_path>/-/issues/<iid>')}))
                sys.exit(1)

        elif url_type == 'mr':
            if gitlab_url:
                url_host = urlparse(url).hostname or ''
                gitlab_host = urlparse(gitlab_url).hostname or ''
                if gitlab_host and url_host and url_host != gitlab_host:
                    print(json.dumps({'error': _msg(f'URL 主机名 {url_host} 与 GITLAB_URL {gitlab_host} 不匹配', f'URL hostname {url_host} does not match GITLAB_URL {gitlab_host}')}))
                    sys.exit(1)
            m = re.match(r'https?://[^/]+/(.+?)/-/merge_requests/(\d+)', url)
            if m:
                print(json.dumps({'project_path': m.group(1), 'mr_iid': int(m.group(2))}))
            else:
                print(json.dumps({'error': _msg('URL 格式不匹配，期望：https://<host>/<project_path>/-/merge_requests/<iid>', 'URL format mismatch, expected: https://<host>/<project_path>/-/merge_requests/<iid>')}))
                sys.exit(1)

        elif url_type == 'project':
            url = url.rstrip('/')
            if re.search(r'/-/issues/\d+', url):
                print(json.dumps({'error': _msg('这是 issue URL，请使用 parse-url issue', 'This is an issue URL, use parse-url issue')}))
                sys.exit(1)
            if re.search(r'/-/merge_requests/\d+', url):
                print(json.dumps({'error': _msg('这是 MR URL，请使用 parse-url mr', 'This is an MR URL, use parse-url mr')}))
                sys.exit(1)
            url = re.sub(r'/-/.*$', '', url).rstrip('/')
            m = re.match(r'https?://[^/]+/(.+)', url)
            if m:
                project_path = re.sub(r'\.git$', '', m.group(1))
                print(json.dumps({'project_path': project_path}))
            else:
                print(json.dumps({'error': _msg('URL 格式不匹配，期望：https://<host>/<project_path>', 'URL format mismatch, expected: https://<host>/<project_path>')}))
                sys.exit(1)
        else:
            print(_msg(f'未知 URL 类型: {url_type}，支持 issue/mr/project', f'Unknown URL type: {url_type}, supported: issue/mr/project'), file=sys.stderr)
            sys.exit(4)

    elif action == 'resolve-project':
        try:
            data = json.load(sys.stdin)
            print(json.dumps(_extract_project_data(data)))
        except (json.JSONDecodeError, ValueError) as e:
            print(json.dumps({'error': _msg(f'JSON 解析失败: {e}', f'JSON parse error: {e}')}), file=sys.stderr)
            sys.exit(1)
        except KeyError as e:
            print(json.dumps({'error': _msg(f'项目信息解析失败: 缺少字段 {e}', f'Project info parse error: missing field {e}')}), file=sys.stderr)
            sys.exit(1)

    elif action == 'find-member':
        if len(sys.argv) < 3:
            print(_msg('用法: json-helper.py find-member <username>', 'Usage: json-helper.py find-member <username>'), file=sys.stderr)
            sys.exit(4)
        username = sys.argv[2]
        try:
            members = json.load(sys.stdin)
            if not isinstance(members, list):
                print(json.dumps({'error': _msg('成员查询返回格式异常', 'Member query returned unexpected format')}), file=sys.stderr)
                sys.exit(1)
            for m in members:
                if m.get('username') == username:
                    print(json.dumps({'user_id': m['id'], 'username': m['username'], 'name': m.get('name', '')}))
                    sys.exit(0)
            print(json.dumps({'error': _msg(f'用户 {username} 不在项目成员中', f'User {username} not a project member')}))
            sys.exit(1)
        except (json.JSONDecodeError, KeyError) as e:
            print(json.dumps({'error': _msg(f'成员信息解析失败: {e}', f'Member info parse error: {e}')}), file=sys.stderr)
            sys.exit(1)

    elif action == 'issue-payload':
        if len(sys.argv) < 3:
            print(_msg('用法: json-helper.py issue-payload <title> [labels]', 'Usage: json-helper.py issue-payload <title> [labels]'), file=sys.stderr)
            sys.exit(4)
        title = sys.argv[2]
        labels = sys.argv[3] if len(sys.argv) > 3 else ''
        desc = sys.stdin.read()
        data = {'title': title, 'description': desc}
        if labels:
            data['labels'] = labels
        print(json.dumps(data))

    elif action == 'labels-payload':
        if len(sys.argv) < 3:
            print(_msg('用法: json-helper.py labels-payload <add> [remove]', 'Usage: json-helper.py labels-payload <add> [remove]'), file=sys.stderr)
            sys.exit(4)
        add_labels = sys.argv[2]
        remove_labels = sys.argv[3] if len(sys.argv) > 3 else ''
        data = {'add_labels': add_labels}
        if remove_labels:
            data['remove_labels'] = remove_labels
        print(json.dumps(data))

    elif action == 'description-payload':
        desc = sys.stdin.read()
        print(json.dumps({'description': desc}))

    elif action == 'mr-payload':
        if len(sys.argv) < 7:
            print(_msg('用法: json-helper.py mr-payload <src> <tgt> <title> <rm> <squash>', 'Usage: json-helper.py mr-payload <src> <tgt> <title> <rm> <squash>'), file=sys.stderr)
            sys.exit(4)
        desc = sys.stdin.read()
        print(json.dumps({
            'source_branch': sys.argv[2],
            'target_branch': sys.argv[3],
            'title': sys.argv[4],
            'description': desc,
            'remove_source_branch': sys.argv[5] == 'true',
            'squash': sys.argv[6] == 'true'
        }))

    elif action == 'ids-payload':
        if len(sys.argv) < 4:
            print(_msg('用法: json-helper.py ids-payload <field> <ids>', 'Usage: json-helper.py ids-payload <field> <ids>'), file=sys.stderr)
            sys.exit(4)
        field = sys.argv[2]
        ids_str = sys.argv[3]
        try:
            ids = []
            if ids_str.strip():
                for x in ids_str.split(','):
                    x = x.strip()
                    if x:
                        try:
                            ids.append(int(x))
                        except ValueError:
                            print(json.dumps({'error': _msg(f'{field} 包含非法值: "{x}"', f'{field} contains invalid value: "{x}"')}))
                            sys.exit(1)
        except Exception as e:
            print(json.dumps({'error': _msg(f'{field} 处理失败: {e}', f'{field} processing failed: {e}')}))
            sys.exit(1)
        print(json.dumps({field: ids}))

    elif action == 'merge-arrays':
        result = []
        for line in sys.stdin:
            line = line.strip()
            if line:
                try:
                    data = json.loads(line)
                    if isinstance(data, list):
                        result.extend(data)
                except (json.JSONDecodeError, ValueError) as e:
                    print(_msg(f'警告: 忽略无效 JSON 行: {e}', f'Warning: ignoring invalid JSON line: {e}'), file=sys.stderr)
        print(json.dumps(result))

    elif action == 'render-mr-template':
        # 渲染 MR 描述模板
        # 用法：json-helper.py render-mr-template <template_file> <issue_iid> <issue_title> [description_file]
        if len(sys.argv) < 5:
            print(_msg('用法: json-helper.py render-mr-template <template_file> <issue_iid> <issue_title> [description_file]', 'Usage: json-helper.py render-mr-template <template_file> <issue_iid> <issue_title> [description_file]'), file=sys.stderr)
            sys.exit(4)
        template_file = sys.argv[2]
        issue_iid = sys.argv[3]
        issue_title = sys.argv[4]
        description_file = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else ''

        template = ''
        try:
            with open(template_file) as f:
                template = f.read()
        except FileNotFoundError:
            pass

        output = template
        output = output.replace('{issue_iid}', issue_iid)
        output = output.replace('{issue_title}', issue_title)

        if description_file:
            try:
                with open(description_file) as f:
                    desc = f.read().strip()
                output = output.replace('{changes_description}', desc)
            except FileNotFoundError:
                output = output.replace('{changes_description}', _msg('（待填写）', '(to be filled)'))
        else:
            output = output.replace('{changes_description}', _msg('（待填写）', '(to be filled)'))

        print(output)

    elif action == 'get-field':
        # 从 stdin JSON 对象中提取单个字段值
        # 用法：echo '{"user_id": 42}' | json-helper.py get-field user_id → 42
        if len(sys.argv) < 3:
            print(_msg('用法: json-helper.py get-field <field_name>', 'Usage: json-helper.py get-field <field_name>'), file=sys.stderr)
            sys.exit(4)
        field = sys.argv[2]
        try:
            data = json.load(sys.stdin)
            value = data.get(field, '')
            print(value if value != '' else '', end='')
        except (json.JSONDecodeError, ValueError) as e:
            print(_msg(f'JSON 解析失败: {e}', f'JSON parse error: {e}'), file=sys.stderr)
            sys.exit(1)

    else:
        print(_msg(f'未知操作: {action}', f'Unknown action: {action}'), file=sys.stderr)
        print(_msg('用法: json-helper.py <action> [args...]', 'Usage: json-helper.py <action> [args...]'), file=sys.stderr)
        print('Actions: body-payload, count, url-encode, parse-url, resolve-project,', file=sys.stderr)
        print('         find-member, issue-payload, labels-payload, description-payload,', file=sys.stderr)
        print('         mr-payload, ids-payload, merge-arrays, render-mr-template, get-field', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

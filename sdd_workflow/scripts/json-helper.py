#!/usr/bin/env python3
"""SDD Workflow — JSON 操作辅助工具

用法：
  python3 json-helper.py body-payload          # stdin → {"body": "<content>"}
  python3 json-helper.py count                 # stdin JSON array → 数组长度
  python3 json-helper.py url-encode <string>   # URL 编码
  python3 json-helper.py parse-url <type> <url> [gitlab_url]  # 解析 issue/mr/project URL
  python3 json-helper.py resolve-project       # stdin JSON → project id/name/path
  python3 json-helper.py get-project-namespace # stdin JSON → namespace_id/kind/repo_name
  python3 json-helper.py find-member <username> # stdin JSON members → find user
  python3 json-helper.py issue-payload <title> [labels]  # stdin desc → issue JSON
  python3 json-helper.py labels-payload <add> [remove]   # → labels JSON
  python3 json-helper.py description-payload   # stdin desc → {"description": "..."}
  python3 json-helper.py mr-payload <src> <tgt> <title> <rm> <squash>  # stdin desc → MR JSON
  python3 json-helper.py ids-payload <field> <ids>  # → {"field": [ids]}
  python3 json-helper.py merge-arrays          # stdin JSON lines → merged array
  python3 json-helper.py render-mr-template <tpl> <iid> <title> [desc_file]  # 渲染 MR 模板
  python3 json-helper.py get-field <field>     # stdin JSON object → field value
  python3 json-helper.py parse-wiki-labels <repo_name>  # stdin wiki markdown → matched labels (comma-separated)
  python3 json-helper.py parse-wiki-type-label <type>   # stdin wiki markdown → type label (comma-separated)
"""

import json
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
            print('用法: json-helper.py url-encode <string>', file=sys.stderr)
            sys.exit(4)
        print(quote(sys.argv[2], safe=''))

    elif action == 'parse-url':
        if len(sys.argv) < 4:
            print('用法: json-helper.py parse-url <type> <url> [gitlab_url]', file=sys.stderr)
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
                    print(json.dumps({'error': f'URL 主机名 {url_host} 与 GITLAB_URL {gitlab_host} 不匹配'}))
                    sys.exit(1)
            m = re.match(r'https?://[^/]+/(.+?)/-/issues/(\d+)', url)
            if m:
                print(json.dumps({'project_path': m.group(1), 'issue_iid': int(m.group(2))}))
            else:
                print(json.dumps({'error': 'URL 格式不匹配，期望：https://<host>/<project_path>/-/issues/<iid>'}))
                sys.exit(1)

        elif url_type == 'mr':
            if gitlab_url:
                url_host = urlparse(url).hostname or ''
                gitlab_host = urlparse(gitlab_url).hostname or ''
                if gitlab_host and url_host and url_host != gitlab_host:
                    print(json.dumps({'error': f'URL 主机名 {url_host} 与 GITLAB_URL {gitlab_host} 不匹配'}))
                    sys.exit(1)
            m = re.match(r'https?://[^/]+/(.+?)/-/merge_requests/(\d+)', url)
            if m:
                print(json.dumps({'project_path': m.group(1), 'mr_iid': int(m.group(2))}))
            else:
                print(json.dumps({'error': 'URL 格式不匹配，期望：https://<host>/<project_path>/-/merge_requests/<iid>'}))
                sys.exit(1)

        elif url_type == 'project':
            url = url.rstrip('/')
            if re.search(r'/-/issues/\d+', url):
                print(json.dumps({'error': '这是 issue URL，请使用 parse-url issue'}))
                sys.exit(1)
            if re.search(r'/-/merge_requests/\d+', url):
                print(json.dumps({'error': '这是 MR URL，请使用 parse-url mr'}))
                sys.exit(1)
            url = re.sub(r'/-/.*$', '', url).rstrip('/')
            m = re.match(r'https?://[^/]+/(.+)', url)
            if m:
                project_path = re.sub(r'\.git$', '', m.group(1))
                print(json.dumps({'project_path': project_path}))
            else:
                print(json.dumps({'error': 'URL 格式不匹配，期望：https://<host>/<project_path>'}))
                sys.exit(1)
        else:
            print(f'未知 URL 类型: {url_type}，支持 issue/mr/project', file=sys.stderr)
            sys.exit(4)

    elif action == 'resolve-project':
        try:
            data = json.load(sys.stdin)
            print(json.dumps(_extract_project_data(data)))
        except (json.JSONDecodeError, ValueError) as e:
            print(json.dumps({'error': f'JSON 解析失败: {e}'}), file=sys.stderr)
            sys.exit(1)
        except KeyError as e:
            print(json.dumps({'error': f'项目信息解析失败: 缺少字段 {e}'}), file=sys.stderr)
            sys.exit(1)

    elif action == 'get-project-namespace':
        try:
            data = json.load(sys.stdin)
            ns = data.get('namespace', {})
            print(json.dumps({
                'namespace_id': ns.get('id'),
                'namespace_kind': ns.get('kind', ''),
                'repo_name': data.get('path', '')
            }))
        except (json.JSONDecodeError, ValueError) as e:
            print(json.dumps({'error': f'JSON 解析失败: {e}'}), file=sys.stderr)
            sys.exit(1)

    elif action == 'find-member':
        if len(sys.argv) < 3:
            print('用法: json-helper.py find-member <username>', file=sys.stderr)
            sys.exit(4)
        username = sys.argv[2]
        try:
            members = json.load(sys.stdin)
            if not isinstance(members, list):
                print(json.dumps({'error': '成员查询返回格式异常'}), file=sys.stderr)
                sys.exit(1)
            for m in members:
                if m.get('username') == username:
                    print(json.dumps({'user_id': m['id'], 'username': m['username'], 'name': m.get('name', '')}))
                    sys.exit(0)
            print(json.dumps({'error': f'用户 {username} 不在项目成员中'}))
            sys.exit(1)
        except (json.JSONDecodeError, KeyError) as e:
            print(json.dumps({'error': f'成员信息解析失败: {e}'}), file=sys.stderr)
            sys.exit(1)

    elif action == 'issue-payload':
        if len(sys.argv) < 3:
            print('用法: json-helper.py issue-payload <title> [labels]', file=sys.stderr)
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
            print('用法: json-helper.py labels-payload <add> [remove]', file=sys.stderr)
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
            print('用法: json-helper.py mr-payload <src> <tgt> <title> <rm> <squash>', file=sys.stderr)
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
            print('用法: json-helper.py ids-payload <field> <ids>', file=sys.stderr)
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
                            print(json.dumps({'error': f'{field} 包含非法值: "{x}"'}))
                            sys.exit(1)
        except Exception as e:
            print(json.dumps({'error': f'{field} 处理失败: {e}'}))
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
                    print(f'警告: 忽略无效 JSON 行: {e}', file=sys.stderr)
        print(json.dumps(result))

    elif action == 'render-mr-template':
        # 渲染 MR 描述模板
        # 用法：json-helper.py render-mr-template <template_file> <issue_iid> <issue_title> [description_file]
        if len(sys.argv) < 5:
            print('用法: json-helper.py render-mr-template <template_file> <issue_iid> <issue_title> [description_file]', file=sys.stderr)
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
                output = output.replace('{changes_description}', '（待填写）')
        else:
            output = output.replace('{changes_description}', '（待填写）')

        print(output)

    elif action == 'parse-wiki-labels':
        # 从 GitLab Wiki API JSON 响应中解析仓库-标签映射，返回 repo_name 对应的标签（逗号分隔）
        # 输入：stdin 为 get-group-wiki-page 返回的完整 JSON（{"content": "..."}）
        # 格式：## 标签名 + - 仓库名
        if len(sys.argv) < 3:
            print('用法: json-helper.py parse-wiki-labels <repo_name>', file=sys.stderr)
            sys.exit(4)
        repo_name = sys.argv[2].strip()
        try:
            raw = sys.stdin.read()
            # strict=False 允许 JSON 字符串中包含实际的控制字符（如 GitLab wiki API 返回的 CR/LF）
            data = json.loads(raw, strict=False)
            content = data.get('content', '')
        except (json.JSONDecodeError, ValueError):
            # 非 JSON 格式，直接当作 wiki 内容文本处理
            content = raw if 'raw' in dir() else ''
        current_label = None
        matched_labels = []
        for line in content.splitlines():
            line = line.strip()
            if line.startswith('## '):
                current_label = line[3:].strip()
            elif line.startswith('- ') and current_label:
                name = line[2:].strip()
                if name == repo_name:
                    matched_labels.append(current_label)
        print(','.join(matched_labels))

    elif action == 'parse-wiki-type-label':
        # 从 GitLab Wiki sdd-configuration 页面中解析「创建Issue type标签映射」配置
        # 根据 issue type（如 requirement/bug）返回对应标签（逗号分隔）
        # 输入：stdin 为 get-group-wiki-page 返回的完整 JSON（{"content": "..."}）
        if len(sys.argv) < 3:
            print('用法: json-helper.py parse-wiki-type-label <type>', file=sys.stderr)
            sys.exit(4)
        issue_type = sys.argv[2].strip().lower()
        try:
            raw = sys.stdin.read()
            data = json.loads(raw, strict=False)
            content = data.get('content', '')
        except (json.JSONDecodeError, ValueError):
            content = raw if 'raw' in dir() else ''
        in_type_section = False
        current_type = None
        matched_labels = []
        for line in content.splitlines():
            line = line.strip()
            if line.startswith('# ') and '创建Issue type标签映射' in line:
                in_type_section = True
                current_type = None
            elif line.startswith('# ') and in_type_section:
                break  # 进入下一个顶级章节，退出
            elif in_type_section and line.startswith('## '):
                current_type = line[3:].strip().lower()
            elif in_type_section and line.startswith('- ') and current_type == issue_type:
                matched_labels.append(line[2:].strip())
        print(','.join(matched_labels))

    elif action == 'get-field':
        # 从 stdin JSON 对象中提取单个字段值
        # 用法：echo '{"user_id": 42}' | json-helper.py get-field user_id → 42
        if len(sys.argv) < 3:
            print('用法: json-helper.py get-field <field_name>', file=sys.stderr)
            sys.exit(4)
        field = sys.argv[2]
        try:
            data = json.load(sys.stdin)
            value = data.get(field, '')
            print(value if value != '' else '', end='')
        except (json.JSONDecodeError, ValueError) as e:
            print(f'JSON 解析失败: {e}', file=sys.stderr)
            sys.exit(1)

    else:
        print(f'未知操作: {action}', file=sys.stderr)
        print('用法: json-helper.py <action> [args...]', file=sys.stderr)
        print('Actions: body-payload, count, url-encode, parse-url, resolve-project,', file=sys.stderr)
        print('         find-member, issue-payload, labels-payload, description-payload,', file=sys.stderr)
        print('         mr-payload, ids-payload, merge-arrays, render-mr-template, get-field', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()

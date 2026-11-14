import os
import re
import sys

def main():
    log_path = sys.argv[1] if len(sys.argv) > 1 else 'test_output.log'
    exit_code = int(sys.argv[2]) if len(sys.argv) > 2 else 1

    if not os.path.exists(log_path):
        print(f"::error title=Test Log Missing::Could not find {log_path}")
        sys.exit(exit_code)

    with open(log_path, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()

    summary_file = os.environ.get('GITHUB_STEP_SUMMARY')

    # Find failures wrapped by flutter runner in ::group::❌ ... ::endgroup::
    pattern = re.compile(r'::group::❌\s*(.*?)\n(.*?)::endgroup::', re.DOTALL)
    matches = pattern.findall(text)

    if matches:
        if summary_file:
            with open(summary_file, 'a', encoding='utf-8') as sf:
                sf.write(f"### ❌ {len(matches)} Flutter Test Failures\n\n")

        for raw_title, raw_body in matches:
            title_clean = raw_title.strip()
            # Try to extract file path and test description
            m_path = re.search(r'(test/[^\s:]+\.dart):\s*(.*)', title_clean)
            if not m_path:
                m_path = re.search(r'/([^/]+/test/[^\s:]+\.dart):\s*(.*)', title_clean)

            file_param = ""
            line_param = ""
            desc = title_clean
            if m_path:
                rel_path = m_path.group(1)
                desc = m_path.group(2)
                file_param = f"file={rel_path},"
                m_line = re.search(re.escape(rel_path) + r'[:\s]+(?:line\s+)?(\d+)', raw_body)
                if m_line:
                    line_param = f"line={m_line.group(1)},"

            # Clean body and truncate to 600 chars to fit within GitHub annotation safely
            clean_body = raw_body.strip()
            if len(clean_body) > 600:
                clean_body = clean_body[:597] + "..."
            escaped_body = clean_body.replace('\r', '').replace('\n', '%0A')

            clean_desc = desc.replace('(failed)', '').strip()
            if len(clean_desc) > 80:
                clean_desc = clean_desc[:77] + "..."

            print(f"::error {file_param}{line_param}title={clean_desc}::{escaped_body}")

            if summary_file:
                with open(summary_file, 'a', encoding='utf-8') as sf:
                    sf.write(f"#### `{clean_desc}`\n```\n{clean_body}\n```\n\n")
    else:
        # Fallback: couldn't find ::group:: blocks
        tail = text[-2000:].strip()
        escaped_tail = tail.replace('\r', '').replace('\n', '%0A')
        print(f"::error title=Flutter Test Failed::{escaped_tail}")
        if summary_file:
            with open(summary_file, 'a', encoding='utf-8') as sf:
                sf.write(f"### ❌ Flutter Test Failed\n```\n{tail}\n```\n")

    sys.exit(exit_code)

if __name__ == '__main__':
    main()

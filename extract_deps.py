import os
import ast
import sys
import re

fallback_std_libs = {
    'abc', 'argparse', 'ast', 'asyncio', 'base64', 'binascii', 'bisect', 'builtins', 'calendar',
    'cmath', 'cmd', 'codecs', 'collections', 'concurrent', 'contextlib', 'copy', 'csv', 'ctypes',
    'dataclasses', 'datetime', 'decimal', 'difflib', 'dis', 'email', 'enum', 'errno', 'exceptions',
    'filecmp', 'fileinput', 'fnmatch', 'fractions', 'functools', 'gc', 'glob', 'gzip', 'hashlib',
    'heapq', 'hmac', 'html', 'http', 'importlib', 'inspect', 'io', 'ipaddress', 'itertools', 'json',
    'keyword', 'logging', 'lzma', 'math', 'mmap', 'modulefinder', 'multiprocessing', 'numbers',
    'operator', 'os', 'pathlib', 'pickle', 'pkgutil', 'platform', 'pprint', 'profile', 'pstats',
    'py_compile', 'pyclbr', 'pydoc', 'queue', 'random', 're', 'readline', 'runpy', 'sched', 'secrets',
    'select', 'selectors', 'shlex', 'shutil', 'signal', 'site', 'smtplib', 'socket', 'socketserver',
    'sqlite3', 'ssl', 'stat', 'statistics', 'string', 'stringprep', 'struct', 'subprocess', 'sys',
    'sysconfig', 'tabnanny', 'tarfile', 'tempfile', 'test', 'textwrap', 'threading', 'time',
    'timeit', 'tkinter', 'token', 'tokenize', 'trace', 'traceback', 'tracemalloc', 'tty', 'turtle',
    'turtledemo', 'types', 'typing', 'unittest', 'urllib', 'uuid', 'venv', 'warnings', 'weakref',
    'webbrowser', 'winreg', 'wsgiref', 'xml', 'xmlrpc', 'zipapp', 'zipfile', 'zipimport', 'zlib', 'glob', 'pwd', 'grp'
}

std_libs = getattr(sys, 'stdlib_module_names', fallback_std_libs)
std_libs = set(std_libs).union(fallback_std_libs)

def get_imports(path):
    imports = set()
    for root, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ('__pycache__', 'venv', 'env', 'checkpoints')]
        for file in files:
            if file.endswith('.py'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        tree = ast.parse(f.read())
                    for node in ast.walk(tree):
                        if isinstance(node, ast.Import):
                            for alias in node.names:
                                imports.add(alias.name.split('.')[0])
                        elif isinstance(node, ast.ImportFrom):
                            if node.module and node.level == 0:
                                imports.add(node.module.split('.')[0])
                except Exception as e:
                    pass
    return imports

all_imports = get_imports(os.getcwd())

# Define local modules directly
local_modules = {'verl', 'utils', 'eval', 'grader', 'calculate_metrics', 'extract_deps', 'setup'}

mapped_pkgs = {
    'yaml': 'pyyaml',
    'PIL': 'Pillow',
    'dotenv': 'python-dotenv',
    'huggingface_hub': 'huggingface-hub',
    'bs4': 'beautifulsoup4',
    'sklearn': 'scikit-learn',
    'cv2': 'opencv-python',
    'flash_attn': 'flash-attn',
    'liger_kernel': 'liger-kernel',
    'hydra': 'hydra-core'
}

third_party = set()
for imp in all_imports:
    if imp not in std_libs and imp not in local_modules and not imp.startswith('_'):
        actual_pkg = mapped_pkgs.get(imp, imp)
        third_party.add(actual_pkg)

# Parse setup.py
setup_deps = set()
try:
    with open('setup.py', 'r', encoding='utf-8') as f:
        content = f.read()
    # Find list inside install_requires = [...]
    match = re.search(r'install_requires\s*=\s*\[(.*?)\]', content, re.DOTALL)
    if match:
        items = re.findall(r"['\"]([^'\"]+)['\"]", match.group(1))
        for item in items:
            pkg = re.split(r'[<>=]', item)[0]
            setup_deps.add(pkg)
            
    # Also extras_require
    for req_list in ['TEST_REQUIRES', 'PRIME_REQUIRES', 'GEO_REQUIRES', 'GPU_REQUIRES']:
        match = re.search(fr'{req_list}\s*=\s*\[(.*?)\]', content, re.DOTALL)
        if match:
            items = re.findall(r"['\"]([^'\"]+)['\"]", match.group(1))
            for item in items:
                pkg = re.split(r'[<>=]', item)[0]
                setup_deps.add(pkg)
except Exception as e:
    print(f"Error parsing setup.py: {e}")

all_deps = third_party.union(setup_deps)

# Clean up any residual non-packages or duplicates
final_deps = sorted(list(all_deps))

with open('requirements.txt', 'w', encoding='utf-8') as f:
    for pkg in final_deps:
        f.write(pkg + '\n')
print(f"Written dependencies to requirements.txt")

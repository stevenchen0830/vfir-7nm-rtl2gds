"""Portable relative manifest paths; do not rewrite historical hash records."""
from pathlib import Path, PurePosixPath


def evidence_path(root, name):
    relative=PurePosixPath(str(name).replace('\\','/'))
    if (relative.is_absolute() or not relative.parts or '..' in relative.parts
            or ':' in relative.parts[0]):
        raise ValueError('Expected a repository-relative evidence path: '+str(name))
    root=Path(root).resolve()
    target=root.joinpath(*relative.parts).resolve()
    if not target.is_relative_to(root): raise ValueError('Evidence path escapes its root')
    return target

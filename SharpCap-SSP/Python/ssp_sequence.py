"""
SSP Sequence Model
==================

Data model and file I/O for automated PEP sequence runs. Phase 2 of the
sequencer work (see SEQUENCER_DEVELOPMENT.md). Pure Python: no UI, no clr and
no SharpCap imports, so it is importable from tests and the standalone
interpreter.

A sequence is an ordered list of SequenceStep objects plus run-length limits
(``max_minutes`` / ``max_observations``) and an optional pass cap (``repeat``).

Step kinds (see SEQUENCER_DEVELOPMENT.md SS3.2):
    GOTO, MEASURE, SKY, FILTER, WAIT, WAIT_UNTIL, ABORT_IF, REPEAT, END

Formats:
    * .ssp-style text: comma-separated "COMMAND,value" (legacy-compatible)
    * JSON: the native format

Author: pep-ssp-tools project
Version: 0.2.0 (Phase 2)
"""

import json
import os
import re


class SequenceParseError(Exception):
    """Raised when a .ssp-style sequence file cannot be parsed."""
    pass


class SequenceStep(object):
    """One step in a PEP sequence. ``kind`` selects which params are used."""

    def __init__(self, kind, **params):
        self.kind = str(kind).upper()
        self.params = params

    def __repr__(self):
        return "SequenceStep(%r, %r)" % (self.kind, self.params)


class PEPSequence(object):
    """Ordered step list plus run-length limits.

    Attributes:
        name: display name
        steps: list of SequenceStep
        max_minutes: stop after this many minutes (None = no minute limit)
        max_observations: stop after this many measurements (None = unlimited)
        repeat: number of full passes over ``steps`` (None or 0 = repeat until a
                length limit is reached or the run is stopped)
    """

    def __init__(self, name="Untitled"):
        self.name = name
        self.steps = []
        self.max_minutes = None
        self.max_observations = None
        self.repeat = None

    def add(self, step):
        """Append a SequenceStep (or subclass) and return it."""
        self.steps.append(step)
        return step

    def add_step(self, kind, **params):
        """Append a new SequenceStep(kind, **params) and return it."""
        return self.add(SequenceStep(kind, **params))

    def get_count(self):
        return len(self.steps)

    def __repr__(self):
        return "PEPSequence(%r, %d steps)" % (self.name, len(self.steps))


# --- value helpers -----------------------------------------------------------

def _to_int(value, default=None):
    try:
        return int(str(value).strip())
    except (ValueError, TypeError):
        return default


def _to_float(value, default=None):
    try:
        return float(str(value).strip())
    except (ValueError, TypeError):
        return default


_OFFSET_RE = re.compile(r'offset\s*=\s*([-+0-9.]+)\s*,\s*([-+0-9.]+)')

# Keys coerced to numbers when a MEASURE/SKY step is built
_MEASURE_FLOATS = ('integ', 'd_ra_h', 'd_dec_deg', 'ra', 'dec')
_MEASURE_INTS = ('gain', 'interval', 'seconds', 'count')


def _parse_kv(rest):
    """Parse 'k=v, k=v' pairs.

    Also supports the shorthand 'offset=ra,dec' which expands to d_ra_h and
    d_dec_deg (the comma inside the offset is handled before the split).
    """
    params = {}
    if not rest:
        return params
    text = rest
    match = _OFFSET_RE.search(text)
    if match:
        params['d_ra_h'] = _to_float(match.group(1))
        params['d_dec_deg'] = _to_float(match.group(2))
        text = text[:match.start()] + text[match.end():]
    for token in text.split(','):
        token = token.strip()
        if not token or '=' not in token:
            continue
        key, value = token.split('=', 1)
        params[key.strip()] = value.strip()
    return params


def _coerce_measure(params):
    """Coerce known MEASURE/SKY keys to int/float; leave the rest as strings."""
    out = {}
    for key, value in params.items():
        if key in _MEASURE_FLOATS:
            out[key] = _to_float(value, value)
        elif key in _MEASURE_INTS:
            out[key] = _to_int(value, value)
        else:
            out[key] = value
    return out

# --- .ssp-style text parsing -------------------------------------------------

def _parse_goto(rest):
    """Build a GOTO step from 'V' | 'RA,Dec' | 'OFFSET,d_ra,d_dec'."""
    parts = [p.strip() for p in rest.split(',') if p.strip() != '']
    if not parts:
        return SequenceStep('GOTO', star_ref='V')
    if len(parts) == 1:
        return SequenceStep('GOTO', star_ref=parts[0].upper())
    if len(parts) == 2:
        return SequenceStep('GOTO', ra=_to_float(parts[0]), dec=_to_float(parts[1]))
    return SequenceStep('GOTO', star_ref=parts[0].upper(),
                        d_ra_h=_to_float(parts[1]), d_dec_deg=_to_float(parts[2]))


def _merge_pending(params, pending):
    """Fill missing MEASURE params from legacy parse-time state."""
    merged = dict(params)
    for key in ('object', 'catalog', 'gain', 'integ', 'interval'):
        if key not in merged and key in pending:
            merged[key] = pending[key]
    return merged


def _apply_command(seq, cmd, rest, pending):
    """Apply one parsed command line to the sequence (raises on unknown)."""
    if cmd == 'MAXMINUTES':
        seq.max_minutes = _to_float(rest)
    elif cmd == 'MAXOBS':
        seq.max_observations = _to_int(rest)
    elif cmd == 'REPEAT':
        seq.steps.append(SequenceStep('REPEAT', count=_to_int(rest, 1) or 1))
    elif cmd == 'END':
        seq.steps.append(SequenceStep('END'))
    elif cmd == 'GOTO':
        seq.steps.append(_parse_goto(rest))
    elif cmd in ('MEASURE', 'COUNT'):
        seq.steps.append(SequenceStep('MEASURE',
                                      **_coerce_measure(_merge_pending(_parse_kv(rest), pending))))
    elif cmd == 'SKY':
        params = _merge_pending(_parse_kv(rest), pending)
        label = str(params.pop('label', 'SKYLAST'))
        seq.steps.append(SequenceStep('SKY', label=label, **_coerce_measure(params)))
    elif cmd == 'FILTER':
        seq.steps.append(SequenceStep('FILTER', filter=rest.strip() or None))
    elif cmd in ('WAIT', 'PAUSE'):
        seq.steps.append(SequenceStep('WAIT', seconds=_to_float(rest, 0.0)))
    elif cmd == 'WAIT_UNTIL':
        seq.steps.append(SequenceStep('WAIT_UNTIL', utc_datetime=rest.strip()))
    elif cmd == 'ABORT_IF':
        seq.steps.append(SequenceStep('ABORT_IF',
                                      **_coerce_measure(_parse_kv(rest))))
    # Legacy state setters (applied to later MEASURE/SKY steps)
    elif cmd == 'OBJECT':
        pending['object'] = rest.strip()
    elif cmd == 'GAIN':
        pending['gain'] = rest.strip()
    elif cmd == 'INTEG':
        pending['integ'] = rest.strip()
    elif cmd == 'INTERVAL':
        pending['interval'] = rest.strip()
    elif cmd == 'TELESCOPE':
        seq.steps.append(_parse_goto(rest))
    # Accepted but ignored (no SharpCap-SSP equivalent)
    elif cmd in ('LOAD', 'LOADCATALOG', 'MIRROR'):
        pass
    else:
        raise SequenceParseError("unknown command %r" % cmd)


def parse_ssp_text(text, name="Untitled"):
    """Parse .ssp-style text into a PEPSequence (raises SequenceParseError)."""
    seq = PEPSequence(name=name)
    pending = {}
    for lineno, raw in enumerate(str(text).splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if ',' in line:
            cmd, rest = line.split(',', 1)
        else:
            cmd, rest = line, ''
        cmd = cmd.strip().upper()
        try:
            _apply_command(seq, cmd, rest.strip(), pending)
        except SequenceParseError:
            raise
        except Exception as exc:
            raise SequenceParseError("line %d: %r (%s)" % (lineno, line, exc))
    return seq


def load_ssp_text(path, name=None):
    """Read and parse a .ssp-style sequence file."""
    with open(path, 'r') as handle:
        text = handle.read()
    if name is None:
        import os
        name = os.path.splitext(os.path.basename(path))[0]
    return parse_ssp_text(text, name=name)

# --- serialization -----------------------------------------------------------

def _fmt_num(value):
    if isinstance(value, float) and value == int(value):
        return str(int(value))
    return str(value)


def _kv_suffix(params):
    """Render a param dict as ', k=v, k=v' (sorted for stable output)."""
    if not params:
        return ""
    return ", " + ", ".join("%s=%s" % (k, params[k]) for k in sorted(params))


def _step_to_text(step):
    kind = step.kind
    params = step.params
    if kind == 'GOTO':
        if 'ra' in params and 'dec' in params:
            return "GOTO, %s,%s" % (params['ra'], params['dec'])
        if 'd_ra_h' in params or 'd_dec_deg' in params:
            return "GOTO, OFFSET,%s,%s" % (params.get('d_ra_h', 0),
                                           params.get('d_dec_deg', 0))
        return "GOTO, %s" % params.get('star_ref', 'V')
    if kind == 'MEASURE':
        return "MEASURE" + _kv_suffix(params)
    if kind == 'SKY':
        rest = dict(params)
        label = rest.pop('label', 'SKYLAST')
        return "SKY, label=%s%s" % (label, _kv_suffix(rest))
    if kind == 'FILTER':
        return "FILTER, %s" % (params.get('filter') or '')
    if kind == 'WAIT':
        return "WAIT, %s" % _fmt_num(params.get('seconds', 0))
    if kind == 'WAIT_UNTIL':
        return "WAIT_UNTIL, %s" % params.get('utc_datetime', '')
    if kind == 'ABORT_IF':
        return "ABORT_IF" + _kv_suffix(params)
    if kind == 'REPEAT':
        return "REPEAT, %d" % int(params.get('count', 1))
    if kind == 'END':
        return "END"
    return kind


def serialize_ssp_text(seq):
    """Serialise a PEPSequence to .ssp-style text (ending with a newline)."""
    lines = ["# SSP sequence: %s" % seq.name]
    if seq.max_minutes:
        lines.append("MAXMINUTES, %s" % _fmt_num(seq.max_minutes))
    if seq.max_observations:
        lines.append("MAXOBS, %d" % int(seq.max_observations))
    indent = 0
    for step in seq.steps:
        if step.kind == 'END':
            indent = max(0, indent - 1)
        lines.append(("  " * indent) + _step_to_text(step))
        if step.kind == 'REPEAT':
            indent += 1
    return "\n".join(lines) + "\n"


def save_ssp_text(seq, path):
    """Write a PEPSequence to a .ssp-style text file."""
    with open(path, 'w') as handle:
        handle.write(serialize_ssp_text(seq))


# --- JSON --------------------------------------------------------------------

def to_dict(seq):
    """Convert a PEPSequence to a plain dict (JSON-serialisable)."""
    steps = []
    for step in seq.steps:
        item = dict(step.params)
        item['kind'] = step.kind
        steps.append(item)
    return {
        'name': seq.name,
        'max_minutes': seq.max_minutes,
        'max_observations': seq.max_observations,
        'repeat': seq.repeat,
        'steps': steps,
    }


def from_dict(data):
    """Build a PEPSequence from a plain dict (inverse of to_dict)."""
    seq = PEPSequence(name=data.get('name', 'Untitled'))
    seq.max_minutes = data.get('max_minutes')
    seq.max_observations = data.get('max_observations')
    seq.repeat = data.get('repeat')
    for item in data.get('steps', []):
        item = dict(item)
        kind = item.pop('kind', None)
        if kind is None:
            raise SequenceParseError("step missing 'kind': %r" % (item,))
        seq.steps.append(SequenceStep(kind, **item))
    return seq


def save_json(seq, path):
    """Write a PEPSequence to a JSON file."""
    with open(path, 'w') as handle:
        json.dump(to_dict(seq), handle, indent=2)


def load_json(path):
    """Read a PEPSequence from a JSON file."""
    with open(path, 'r') as handle:
        return from_dict(json.load(handle))


# --- templates ---------------------------------------------------------------

def build_templates():
    """Return the built-in templates as a dict {name: PEPSequence}.

    Each template runs until the sequence's run-length limit (repeat=None); the
    caller/UI applies a default limit if the user has not set one.
    """
    def measure(**overrides):
        params = {'filter': 'V', 'integ': 5.0, 'interval': 3}
        params.update(overrides)
        return SequenceStep('MEASURE', **params)

    templates = {}

    seq = PEPSequence('V-C-V-C')
    for ref in ('V', 'C', 'V', 'C'):
        seq.add_step('GOTO', star_ref=ref)
        seq.add(measure())
    templates['V-C-V-C'] = seq

    seq = PEPSequence('C-V-C')
    for ref in ('C', 'V', 'C'):
        seq.add_step('GOTO', star_ref=ref)
        seq.add(measure())
    templates['C-V-C'] = seq

    seq = PEPSequence('V-C-K')
    for ref in ('V', 'C', 'K'):
        seq.add_step('GOTO', star_ref=ref)
        seq.add(measure())
    templates['V-C-K'] = seq

    return templates


# --- editor field helpers (used by SequenceDialog) ---------------------------

def _kv_text(params):
    """Render a param dict as 'k=v, k=v' (sorted, for the dialog field)."""
    return ", ".join("%s=%s" % (k, params[k]) for k in sorted(params))


def format_step(step, index=None):
    """One-line display string, e.g. '3  MEASURE filter=V, integ=5.0, interval=3'."""
    prefix = ("%d  " % index) if index is not None else ""
    return prefix + _step_to_text(step)


def step_from_fields(kind, value="", label="", params_text=""):
    """Build a SequenceStep from the dialog's fields.

    Args:
        kind: step kind (GOTO / MEASURE / SKY / FILTER / WAIT / WAIT_UNTIL /
              ABORT_IF / REPEAT / END)
        value: kind-specific primary field (GOTO star or coords, FILTER name,
               WAIT seconds, WAIT_UNTIL datetime, REPEAT count)
        label: SKY label (SKY/SKYNEXT/SKYLAST)
        params_text: 'k=v, k=v' pairs (MEASURE/SKY/ABORT_IF, or GOTO coords)
    """
    kind = str(kind).upper()
    if kind == 'GOTO':
        return _parse_goto((value or params_text or 'V').strip())
    if kind == 'MEASURE':
        return SequenceStep('MEASURE', **_coerce_measure(_parse_kv(params_text)))
    if kind == 'SKY':
        params = _coerce_measure(_parse_kv(params_text))
        return SequenceStep('SKY', label=((label or 'SKYLAST').strip() or 'SKYLAST'),
                            **params)
    if kind == 'FILTER':
        return SequenceStep('FILTER', filter=((value or '').strip() or None))
    if kind == 'WAIT':
        return SequenceStep('WAIT', seconds=_to_float(value, 0.0))
    if kind == 'WAIT_UNTIL':
        return SequenceStep('WAIT_UNTIL', utc_datetime=(value or '').strip())
    if kind == 'ABORT_IF':
        return SequenceStep('ABORT_IF', **_coerce_measure(_parse_kv(params_text)))
    if kind == 'REPEAT':
        return SequenceStep('REPEAT', count=_to_int(value, 1) or 1)
    if kind == 'END':
        return SequenceStep('END')
    return SequenceStep(kind)


def fields_from_step(step):
    """Return (kind, value, label, params_text) to populate the editor fields."""
    kind = step.kind
    params = step.params
    if kind == 'GOTO':
        if 'ra' in params and 'dec' in params:
            value = "%s,%s" % (params['ra'], params['dec'])
        elif 'd_ra_h' in params or 'd_dec_deg' in params:
            value = "OFFSET,%s,%s" % (params.get('d_ra_h', 0),
                                      params.get('d_dec_deg', 0))
        else:
            value = params.get('star_ref', 'V')
        return (kind, value, '', '')
    if kind == 'MEASURE':
        return (kind, '', '', _kv_text(params))
    if kind == 'SKY':
        rest = dict(params)
        label = rest.pop('label', 'SKYLAST')
        return (kind, '', label, _kv_text(rest))
    if kind == 'FILTER':
        return (kind, params.get('filter') or '', '', '')
    if kind == 'WAIT':
        return (kind, _fmt_num(params.get('seconds', 0)), '', '')
    if kind == 'WAIT_UNTIL':
        return (kind, params.get('utc_datetime', ''), '', '')
    if kind == 'ABORT_IF':
        return (kind, '', '', _kv_text(params))
    if kind == 'REPEAT':
        return (kind, str(params.get('count', 1)), '', '')
    return (kind, '', '', '')

# --- named sequence storage --------------------------------------------------

def _safe_name(name):
    """Sanitise a sequence name for use as a filename."""
    bad = r'<>:"/\|?*'
    out = ''.join(('_' if ch in bad else ch) for ch in str(name)).strip()
    return out or 'sequence'


def sequences_dir(base_dir):
    """Return (creating if needed) the 'sequences' subdirectory of base_dir."""
    path = os.path.join(base_dir, 'sequences')
    try:
        if not os.path.isdir(path):
            os.makedirs(path)
    except Exception:
        pass
    return path


def list_names(directory):
    """Return the sorted sequence names (*.json, without the extension)."""
    names = []
    try:
        for entry in os.listdir(directory):
            if entry.lower().endswith('.json'):
                names.append(entry[:-5])
    except Exception:
        pass
    names.sort()
    return names


def save_named(seq, directory, name=None):
    """Save seq as <directory>/<name>.json. Returns the file path."""
    if not name:
        name = seq.name
    path = os.path.join(directory, _safe_name(name) + '.json')
    save_json(seq, path)
    return path


def load_named(directory, name):
    """Load <directory>/<name>.json into a PEPSequence."""
    return load_json(os.path.join(directory, _safe_name(name) + '.json'))


def delete_named(directory, name):
    """Delete <directory>/<name>.json. Returns True if a file was removed."""
    try:
        os.remove(os.path.join(directory, _safe_name(name) + '.json'))
        return True
    except Exception:
        return False





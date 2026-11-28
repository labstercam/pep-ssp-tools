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
    GOTO, TARGET, MEASURE, SKY, FILTER, WAIT, WAIT_UNTIL, ABORT_IF, REPEAT, END

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


def _to_bool_int(value):
    """Return 1/0 for truthy/falsey text, else None.

    Accepts 1/0, true/false, yes/no, on/off (case-insensitive) so a step can
    carry e.g. 'plate_solve=0' without needing a dedicated UI control.
    """
    if value is None:
        return None
    if isinstance(value, bool):
        return 1 if value else 0
    if isinstance(value, int):
        return 1 if value else 0
    text = str(value).strip().lower()
    if text in ('1', 'true', 'yes', 'on', 'y'):
        return 1
    if text in ('0', 'false', 'no', 'off', 'n'):
        return 0
    return None


# An RA/Dec offset, written 'offset=dRA,dDec' (canonical) or 'OFFSET,dRA,dDec'
# (legacy GOTO spelling). Used for SKY/MEASURE params and for GOTO (in the Value
# box, the editor Params box, or the .ssp text), so the syntax is identical for
# every command that carries an offset.
_OFFSET_RE = re.compile(
    r'\boffset\b\s*[=,]?\s*([-+0-9.]+)\s*,\s*([-+0-9.]+)', re.IGNORECASE)

# A per-step 'plate_solve=0/1' flag; pulled out before GOTO's comma split so it
# does not become a spurious coordinate part.
_GOTO_FLAG_RE = re.compile(r'plate_solve\s*=\s*([^,\s]+)', re.IGNORECASE)

# A TARGET identifier may be a plain object name / AUID, or be prefixed with
# 'name=' / 'auid=' to force which catalog field is matched.
_TARGET_ID_RE = re.compile(r'^\s*(name|auid)\s*=\s*(.+)$', re.IGNORECASE)

# ...or carry a trailing ', id=name' / ', id=auid' token (the editor's Params box).
_TARGET_FLAG_RE = re.compile(r'id\s*=\s*(name|auid)\b', re.IGNORECASE)

# Keys coerced to numbers when a MEASURE/SKY step is built
_MEASURE_FLOATS = ('integ', 'd_ra_h', 'd_dec_deg', 'ra', 'dec')
_MEASURE_INTS = ('gain', 'interval', 'seconds', 'count')
_BOOL_KEYS = ('plate_solve',)


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
        if key in _BOOL_KEYS:
            coerced = _to_bool_int(value)
            out[key] = coerced if coerced is not None else value
        elif key in _MEASURE_FLOATS:
            out[key] = _to_float(value, value)
        elif key in _MEASURE_INTS:
            out[key] = _to_int(value, value)
        else:
            out[key] = value
    return out

# --- .ssp-style text parsing -------------------------------------------------

def _parse_goto(rest):
    """Build a GOTO step from the .ssp text after 'GOTO,'.

    Accepted forms (an optional 'plate_solve=0/1' token may follow any of them):
        'V' / 'C' / 'K' / 'SKY' / 'OFFSET'   star reference
        'RA,Dec'                              absolute coordinates
        'V, offset=dRA,dDec'                  star + RA/Dec offset
        'RA,Dec, offset=dRA,dDec'             coords + RA/Dec offset
        'V, dRA, dDec'      (legacy)          star + offset
        'OFFSET, dRA, dDec' (legacy)          offset from the variable star

    'offset=dRA,dDec' is pulled out before the comma split (its inner comma would
    otherwise be mistaken for a coordinate separator); the 'plate_solve' token is
    pulled out the same way.
    """
    rest = rest or ''
    flag = None
    match = _GOTO_FLAG_RE.search(rest)
    if match:
        flag = _to_bool_int(match.group(1))
        rest = rest[:match.start()] + rest[match.end():]
    offset = None
    off_match = _OFFSET_RE.search(rest)
    if off_match:
        offset = (_to_float(off_match.group(1), 0.0),
                  _to_float(off_match.group(2), 0.0))
        rest = rest[:off_match.start()] + rest[off_match.end():]
    parts = [p.strip() for p in rest.split(',') if p.strip() != '']
    if not parts:
        step = SequenceStep('GOTO', star_ref='OFFSET' if offset else 'V')
    elif len(parts) == 1:
        step = SequenceStep('GOTO', star_ref=parts[0].upper())
    elif len(parts) == 2:
        step = SequenceStep('GOTO', ra=_to_float(parts[0]), dec=_to_float(parts[1]))
    elif len(parts) == 3:
        # legacy star/ref plus an RA/Dec offset (e.g. 'V,0.0,0.25')
        step = SequenceStep('GOTO', star_ref=parts[0].upper(),
                            d_ra_h=_to_float(parts[1]), d_dec_deg=_to_float(parts[2]))
    else:
        # legacy absolute RA/Dec plus an RA/Dec offset ('12.5,-30.25,0.0,0.25')
        step = SequenceStep('GOTO', ra=_to_float(parts[0]), dec=_to_float(parts[1]),
                            d_ra_h=_to_float(parts[2]), d_dec_deg=_to_float(parts[3]))
    if offset is not None:
        step.params['d_ra_h'] = offset[0]
        step.params['d_dec_deg'] = offset[1]
    if flag is not None:
        step.params['plate_solve'] = flag
    return step


def _parse_goto_offset_values(text):
    """Return (d_ra_h, d_dec_deg) from an OFFSET/offset spec in `text`, else None.

    Accepts 'OFFSET,dRA,dDec' and 'offset=dRA,dDec' (optionally surrounded by
    other params such as 'plate_solve=0'). Used to apply an offset typed in the
    editor Params box on top of whatever the Value box resolves to (a star,
    absolute coords, or nothing = offset from the current target).
    """
    match = _OFFSET_RE.search(text or '')
    if not match:
        return None
    return (_to_float(match.group(1), 0.0), _to_float(match.group(2), 0.0))


def _parse_target(rest):
    """Build a TARGET step from '<identifier>' or 'name=..' / 'auid=..'.

    The identifier is a catalog object name (e.g. 'OMI CET') or an AUID (e.g.
    '000-BBW-425'). When no type is given the resolver tries the name first and
    then the AUID, so most sequences can simply use the plain name. A trailing
    ', id=name' / ', id=auid' token is also accepted (mirrors the editor Params
    box); an explicit type wins over the auto behaviour.
    """
    text = (rest or '').strip()
    id_type = None
    match = _TARGET_ID_RE.match(text)
    if match:
        id_type = match.group(1).lower()
        text = match.group(2).strip()
    flag = _TARGET_FLAG_RE.search(text)
    if flag:
        if id_type is None:
            id_type = flag.group(1).lower()
        text = (text[:flag.start()] + text[flag.end():]).strip().strip(',').strip()
    if not text:
        raise SequenceParseError("TARGET requires an object name or AUID")
    return SequenceStep('TARGET', object=text, id_type=id_type)


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
    elif cmd == 'TARGET':
        seq.steps.append(_parse_target(rest))
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


# RA/Dec coordinates and offsets are shown with a fixed precision so the editor
# never displays the full binary float expansion (e.g. 0.10000000000000001 that
# IronPython's str(float) can produce). Six decimals matches the clipboard
# coordinate format used elsewhere in the app.
_COORD_KEYS = ('ra', 'dec', 'd_ra_h', 'd_dec_deg')
_COORD_DECIMALS = 6


def _fmt_coord(value, places=_COORD_DECIMALS):
    """Format an RA/Dec value or offset with at most ``places`` decimals.

    0.10000000000000001 -> '0.1', 0.25 -> '0.25', 0.0 -> '0'. Non-numeric
    input is returned unchanged (str) so hand-edited text is preserved.
    """
    try:
        number = float(value)
    except (TypeError, ValueError):
        return str(value)
    text = ("%%.%df" % places) % number
    if '.' in text:
        text = text.rstrip('0').rstrip('.')
    return text or '0'


def _fmt_value(key, value):
    """Format one param value (RA/Dec keys get a fixed precision)."""
    if key in _COORD_KEYS:
        return _fmt_coord(value)
    return str(value)


def _kv_suffix(params):
    """Render a param dict as ', k=v, k=v' (sorted for stable output)."""
    if not params:
        return ""
    return ", " + ", ".join("%s=%s" % (k, _fmt_value(k, params[k]))
                            for k in sorted(params))


def _step_to_text(step):
    kind = step.kind
    params = step.params
    if kind == 'GOTO':
        extra = (", plate_solve=%d" % int(params['plate_solve'])
                 if 'plate_solve' in params else "")
        has_offset = ('d_ra_h' in params) or ('d_dec_deg' in params)
        if 'ra' in params and 'dec' in params:
            target = "%s,%s" % (_fmt_coord(params['ra']),
                                _fmt_coord(params['dec']))
        else:
            ref = str(params.get('star_ref', 'V')).upper()
            # OFFSET/SKY with an offset is the default "offset from the
            # variable star" target, so the reference itself is omitted.
            target = '' if (has_offset and ref in ('OFFSET', 'SKY')) else ref
        parts_out = []
        if target:
            parts_out.append(target)
        if has_offset:
            parts_out.append("offset=%s,%s" % (
                _fmt_coord(params.get('d_ra_h', 0)),
                _fmt_coord(params.get('d_dec_deg', 0))))
        if not parts_out:
            parts_out.append(str(params.get('star_ref', 'V')).upper())
        return "GOTO, " + ", ".join(parts_out) + extra
    if kind == 'TARGET':
        ident = params.get('object') or ''
        id_type = params.get('id_type')
        prefix = ("%s=" % id_type) if id_type else ""
        return "TARGET, %s%s" % (prefix, ident)
    if kind == 'MEASURE':
        return "MEASURE" + _kv_suffix(params)
    if kind == 'SKY':
        rest = dict(params)
        label = rest.pop('label', 'SKYLAST')
        offset_text = ""
        if ('d_ra_h' in rest) or ('d_dec_deg' in rest):
            offset_text = ", offset=%s,%s" % (_fmt_coord(rest.pop('d_ra_h', 0)),
                                              _fmt_coord(rest.pop('d_dec_deg', 0)))
        return "SKY, label=%s%s%s" % (label, offset_text, _kv_suffix(rest))
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
    return ", ".join("%s=%s" % (k, _fmt_value(k, params[k]))
                     for k in sorted(params))


def format_step(step, index=None):
    """One-line display string, e.g. '3  MEASURE filter=V, integ=5.0, interval=3'."""
    prefix = ("%d  " % index) if index is not None else ""
    return prefix + _step_to_text(step)


def step_from_fields(kind, value="", label="", params_text=""):
    """Build a SequenceStep from the dialog's fields.

    Args:
        kind: step kind (GOTO / TARGET / MEASURE / SKY / FILTER / WAIT /
              WAIT_UNTIL / ABORT_IF / REPEAT / END)
        value: kind-specific primary field (GOTO star or coords, TARGET object
               name/AUID, FILTER name, WAIT seconds, WAIT_UNTIL datetime,
               REPEAT count)
        label: SKY label (SKY/SKYNEXT/SKYLAST)
        params_text: 'k=v, k=v' pairs (MEASURE/SKY/ABORT_IF, GOTO coords, or
                     TARGET 'id=auid')
    """
    kind = str(kind).upper()
    if kind == 'GOTO':
        # Value holds the target (V/C/K, RA,Dec, OFFSET,dRA,dDec, or blank);
        # the Params box may add an RA/Dec offset ('OFFSET,dRA,dDec' or
        # 'offset=dRA,dDec') and/or 'plate_solve=0/1'. Both are respected: the
        # offset is applied ON TOP of the Value, so 'GOTO V' + an offset gives
        # 'GOTO, V, dRA, dDec'. With a blank Value the offset is taken from the
        # current target's variable star ('GOTO, OFFSET, dRA, dDec').
        params_kv = _parse_kv(params_text)
        offset = _parse_goto_offset_values(params_text)
        if value and value.strip():
            step = _parse_goto(value.strip())
        elif offset is not None:
            step = SequenceStep('GOTO', star_ref='OFFSET')
        else:
            step = _parse_goto('V')
        if offset is not None:
            step.params['d_ra_h'] = offset[0]
            step.params['d_dec_deg'] = offset[1]
        flag = _to_bool_int(params_kv.get('plate_solve'))
        if flag is not None:
            step.params['plate_solve'] = flag
        return step
    if kind == 'TARGET':
        # Value holds the object name or AUID (optionally 'auid=..' / 'name=..');
        # the Params box may add 'id=auid' to force AUID matching.
        text = (value or '').strip()
        id_type = None
        match = _TARGET_ID_RE.match(text)
        if match:
            id_type = match.group(1).lower()
            text = match.group(2).strip()
        forced = (_parse_kv(params_text).get('id') or '').strip().lower()
        if forced in ('name', 'auid'):
            id_type = forced
        return SequenceStep('TARGET', object=(text or None), id_type=id_type)
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
            value = "%s,%s" % (_fmt_coord(params['ra']),
                               _fmt_coord(params['dec']))
        else:
            ref = str(params.get('star_ref', 'V')).upper()
            # An OFFSET/SKY reference with no explicit star is an offset-only
            # step, so the Value box is left blank (the offset shows in Params).
            value = '' if ref in ('OFFSET', 'SKY') else ref
        extra = {}
        if ('d_ra_h' in params) or ('d_dec_deg' in params):
            extra['offset'] = "%s,%s" % (_fmt_coord(params.get('d_ra_h', 0)),
                                         _fmt_coord(params.get('d_dec_deg', 0)))
        if 'plate_solve' in params:
            extra['plate_solve'] = int(params['plate_solve'])
        return (kind, value, '', _kv_text(extra))
    if kind == 'TARGET':
        ident = params.get('object') or ''
        id_type = params.get('id_type')
        return (kind, ident, '', ("id=%s" % id_type) if id_type else '')
    if kind == 'MEASURE':
        return (kind, '', '', _kv_text(params))
    if kind == 'SKY':
        rest = dict(params)
        label = rest.pop('label', 'SKYLAST')
        extra = {}
        if ('d_ra_h' in rest) or ('d_dec_deg' in rest):
            extra['offset'] = "%s,%s" % (_fmt_coord(rest.pop('d_ra_h', 0)),
                                         _fmt_coord(rest.pop('d_dec_deg', 0)))
        extra.update(rest)
        return (kind, '', label, _kv_text(extra))
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

# --- catalog target validation (shared by the editor and the runtime) --------

def find_target_steps(seq):
    """Return [(index, identifier, id_type), ...] for every TARGET step.

    ``index`` is the 1-based position within ``seq.steps`` so the caller can
    report exactly which step references an unknown object.
    """
    found = []
    for i, step in enumerate(seq.steps):
        if step.kind == 'TARGET':
            found.append((i + 1, step.params.get('object') or '',
                          step.params.get('id_type')))
    return found


def resolve_catalog_target(catalog, identifier, id_type=None):
    """Resolve an identifier to a catalog TargetTriple (or None).

    ``id_type`` may be 'name', 'auid', or None/'' (try the name first, then the
    AUID). Returns None when the catalog is missing/empty or the identifier is
    unknown. The catalog only needs ``get_count`` / ``get_target_by_name`` /
    ``get_target_by_auid`` (i.e. ``ssp_catalog.StarCatalog``).
    """
    if catalog is None:
        return None
    try:
        if catalog.get_count() == 0:
            return None
    except Exception:
        return None
    ident = str(identifier or '').strip()
    if not ident:
        return None
    id_type = str(id_type or '').strip().lower()
    try:
        if id_type == 'auid':
            return catalog.get_target_by_auid(ident)
        if id_type == 'name':
            return catalog.get_target_by_name(ident)
        found = catalog.get_target_by_name(ident)
        if found is None:
            found = catalog.get_target_by_auid(ident)
        return found
    except Exception:
        return None


def missing_catalog_targets(seq, catalog):
    """Return [(index, identifier), ...] for TARGET steps not in ``catalog``.

    Returns ``None`` when the catalog is missing or empty, so the caller can
    show a single "catalog not loaded" note instead of listing every target as
    missing. An empty list means every referenced object resolved.
    """
    if catalog is None:
        return None
    try:
        if catalog.get_count() == 0:
            return None
    except Exception:
        return None
    missing = []
    for index, identifier, id_type in find_target_steps(seq):
        if resolve_catalog_target(catalog, identifier, id_type) is None:
            missing.append((index, identifier))
    return missing


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





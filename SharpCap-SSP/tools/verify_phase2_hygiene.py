"""Verification for the Phase 2 hygiene fixes (Part 10.5 of MEMORY_ANALYSIS.md).

Run with CPython (not IronPython):

    python tools/verify_phase2_hygiene.py [path-to-Python-dir]

The SharpCap modules import clr / System.Windows.Forms and cannot be imported outside
SharpCap, so the guards under test are extracted from the shipped source with `ast` and
executed against fakes. Nothing is retyped here, so a passing run proves the deployed
code - not a paraphrase of it - behaves as documented.

Covers:
  * ssp_comm.py   _clear_buffer iteration cap (_CLEAR_BUFFER_MAX_READS)
  * ssp_dataaq.py _get_target_label_bold_font / _on_form_closed  (cached target Font)
  * ssp_allsky.py _get_strikeout_font / _on_form_closed          (cached strikeout Font)

Exit code 0 on success, 1 on any failure.
"""
import ast
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_PY = os.path.normpath(os.path.join(HERE, "..", "Python"))
PYDIR = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_PY

failures = []


def check(label, condition, detail=""):
    if condition:
        print("  PASS  %s" % label)
    else:
        print("  FAIL  %s %s" % (label, detail))
        failures.append(label)


def load(path, names, extra_ns=None):
    """Return (namespace, module_tree) for the named functions in `path`."""
    with open(path, "r", encoding="utf-8") as fh:
        tree = ast.parse(fh.read())
    found = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.FunctionDef) and node.name in names:
            found[node.name] = node
    missing = sorted(set(names) - set(found))
    if missing:
        raise AssertionError("%s: functions not found: %s" % (path, missing))
    ns = dict(extra_ns or {})
    mod = ast.Module(body=[found[n] for n in names], type_ignores=[])
    exec(compile(ast.fix_missing_locations(mod), path, "exec"), ns)
    return ns, tree


def load_module_const(tree, name):
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(
            getattr(t, "id", None) == name for t in node.targets
        ):
            ns = {}
            exec(compile(ast.fix_missing_locations(ast.Module([node], [])),
                         "<const>", "exec"), ns)
            return ns[name]
    raise AssertionError("module constant %s not found" % name)


class Holder(object):
    def __init__(self, port):
        self.port = port


# ----------------------------------------------------------------------
# 1. ssp_comm.py - _clear_buffer iteration cap
# ----------------------------------------------------------------------
print("ssp_comm.py - _clear_buffer iteration cap")
ns, tree = load(os.path.join(PYDIR, "ssp_comm.py"), ["_clear_buffer"])
clear_buffer = ns["_clear_buffer"]
cap = load_module_const(tree, "_CLEAR_BUFFER_MAX_READS")
# The extracted function resolves module globals through `ns`, so publish the
# constant there as well or the cap lookup raises NameError.
ns["_CLEAR_BUFFER_MAX_READS"] = cap

check("cap constant is the int 1000", cap == 1000 and isinstance(cap, int),
      "(got %r)" % (cap,))


class FakePort(object):
    """Reports `total` bytes pending, decreasing by one per read."""

    def __init__(self, total, is_open=True):
        self.IsOpen = is_open
        self.remaining = total
        self.reads = 0

    @property
    def BytesToRead(self):
        if not self.IsOpen:
            raise AssertionError("queried a closed port")
        return self.remaining

    def ReadExisting(self):
        if not self.IsOpen:
            raise AssertionError("read from a closed port")
        self.reads += 1
        self.remaining = max(0, self.remaining - 1)
        return "x"


port = FakePort(5)
clear_buffer(Holder(port))
check("finite buffer drains fully", port.reads == 5 and port.BytesToRead == 0,
      "(reads=%d remaining=%d)" % (port.reads, port.remaining))

port = FakePort(10 ** 9)
clear_buffer(Holder(port))
check("runaway stream stops at the cap", port.reads == cap, "(reads=%d)" % port.reads)

clear_buffer(Holder(FakePort(10 ** 9, is_open=False)))
check("closed port is a no-op", True)

clear_buffer(types.SimpleNamespace(port=None))
check("port=None is a no-op", True)

# ----------------------------------------------------------------------
# 2/3. cached Fonts
# ----------------------------------------------------------------------
class FakeFont(object):
    instances = []

    def __init__(self, *args, **kwargs):
        self.args = args
        self.disposed = False
        FakeFont.instances.append(self)

    def Dispose(self):
        self.disposed = True


class FakeFontStyle(object):
    Bold = "Bold"
    Strikeout = "Strikeout"


FAKES = {"Font": FakeFont, "FontStyle": FakeFontStyle}


def font_cache_case(label, module, getter_name, attr, calls, expect_args, grid=None):
    ns, _ = load(os.path.join(PYDIR, module), [getter_name, "_on_form_closed"], FAKES)
    getter, on_closed = ns[getter_name], ns["_on_form_closed"]

    obj = types.SimpleNamespace()
    if grid is not None:
        obj.grid = grid
    setattr(obj, attr, None)

    del FakeFont.instances[:]
    first = getter(obj)
    check("%s: same instance reused for %d calls" % (label, calls + 1),
          all(getter(obj) is first for _ in range(calls)))
    check("%s: exactly 1 Font allocated" % label, len(FakeFont.instances) == 1,
          "(got %d)" % len(FakeFont.instances))
    check("%s: Font built from %r" % (label, expect_args), first.args == expect_args,
          "(got %r)" % (first.args,))

    on_closed(obj, None, None)
    check("%s: Font disposed on FormClosed" % label, first.disposed)
    check("%s: cache reference cleared" % label, getattr(obj, attr) is None)

    on_closed(obj, None, None)
    check("%s: FormClosed is idempotent" % label, True)

    on_closed(types.SimpleNamespace(), None, None)
    check("%s: FormClosed safe when attribute absent" % label, True)

    on_closed(types.SimpleNamespace(**{attr: None}), None, None)
    check("%s: FormClosed safe when never used" % label, True)


print("ssp_dataaq.py - cached target-label Font")
font_cache_case("target Font", "ssp_dataaq.py",
                "_get_target_label_bold_font", "_target_label_font",
                500, ("Arial", 9, "Bold"))

print("ssp_allsky.py - cached strikeout Font")
font_cache_case("strikeout Font", "ssp_allsky.py",
                "_get_strikeout_font", "_strikeout_font",
                5000, ("GRIDFONT", "Strikeout"),
                grid=types.SimpleNamespace(Font="GRIDFONT"))

# ----------------------------------------------------------------------
print("")
if failures:
    print("FAILED: %d check(s): %s" % (len(failures), "; ".join(failures)))
    sys.exit(1)
print("ALL PHASE 2 HYGIENE CHECKS PASSED")
sys.exit(0)

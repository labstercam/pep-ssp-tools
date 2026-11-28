"""
Test the sequence-engine Phase 1 refactor for SharpCap-SSP
=========================================================

Phase 1 of the sequencer work (see SEQUENCER_DEVELOPMENT.md) extracted the
measurement path out of _on_start into three methods on
SSPDataAcquisitionWindow:

    take_reading(...)            - one PEP measurement, records a data line
    _collect_counts(...)         - the count loop + 6/8 binning + retry
    _filter_position_for_name()  - filter name -> active-bar position

This test drives those REAL methods against a fake window (no photometer, no
SharpCap, no hardware) and checks:

1. take_reading with explicit params records the same arrays/format as _on_start
2. take_reading / _collect_counts honour the _closing and _sequence_abort guards
3. the 6/8 interval pair-binning is unchanged (and the retry/zero fallback works)
4. _filter_position_for_name maps filter names to active-bar positions

Run in IronPython (the app runtime):

    .\\run_ipy_test.ps1 test_sequence.py

The expected data lines below were computed independently (the format is
byte-for-byte the SSPDataq line produced by _format_data_line).
"""

import sys
import os

# Add script directory to path
script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()
if script_dir not in sys.path:
    sys.path.append(script_dir)


def _print_stale_module_hint(module_name, module):
    """Explain a missing-attribute failure caused by a stale deployed module."""
    print("    -> A stale '%s' module was loaded from: %s"
          % (module_name, getattr(module, '__file__', '<unknown>')))
    print("       Copy the updated %s.py into the SharpCap scripts folder and"
          % module_name)
    print("       restart SharpCap so the new module is imported.")


# --- Fakes -------------------------------------------------------------------

class _FakeItems(object):
    """Stand-in for ListBox.ObjectCollection (needs Insert + Count)."""

    def __init__(self):
        self.store = []

    def Insert(self, index, value):
        self.store.insert(index, value)

    @property
    def Count(self):
        return len(self.store)


class _FakeDataListBox(object):
    def __init__(self):
        self.Items = _FakeItems()


class _FakeConfig(object):
    """Minimal SSPConfig stand-in exposing get(key, default)."""

    def __init__(self, values=None):
        self._values = values if values is not None else {}

    def get(self, key, default=None):
        return self._values.get(key, default)


class _FakeComm(object):
    """SSPCommunicator stand-in returning scripted counts.

    Args:
        counts: list of count strings cycled through on success
        fail_first_n: first N get_slow_count calls return failure (retry test)
        always_fail: every get_slow_count call fails (zero fallback test)
        fail_integration / fail_gain: force the config step to fail
        select_filter_result: tuple returned by select_filter
        on_count: optional callback(comm, count_no) run after a success
    """

    def __init__(self, counts=None, fail_first_n=0, always_fail=False,
                 fail_integration=False, fail_gain=False,
                 select_filter_result=(True, 0, "ok"), on_count=None):
        self.is_connected = True
        self.counts = list(counts) if counts is not None else ["00496"]
        self.fail_first_n = fail_first_n
        self.always_fail = always_fail
        self.fail_integration = fail_integration
        self.fail_gain = fail_gain
        self.select_filter_result = select_filter_result
        self.on_count = on_count
        self._idx = 0
        self.integration_calls = []
        self.gain_calls = []
        self.filter_calls = []
        self.count_calls = []

    def set_integration(self, ms):
        self.integration_calls.append(ms)
        if self.fail_integration:
            return (False, "integration failed")
        return (True, "ok")

    def set_gain(self, gain):
        self.gain_calls.append(gain)
        if self.fail_gain:
            return (False, "gain failed")
        return (True, "ok")

    def select_filter(self, position):
        self.filter_calls.append(position)
        return self.select_filter_result

    def get_slow_count(self, ms):
        self.count_calls.append(ms)
        call_no = len(self.count_calls)
        if self.always_fail or call_no <= self.fail_first_n:
            return (False, "", "no ack")
        value = self.counts[self._idx % len(self.counts)]
        self._idx += 1
        if self.on_count is not None:
            self.on_count(self, self._idx)
        return (True, value, "")


# --- DateTime shim (makes the mid-point timestamp deterministic) -------------

class _FakeDT(object):
    """Minimal System.DateTime shim: UtcNow, AddSeconds, ToString."""

    def __init__(self, y, mo, d, h, mi, s):
        self._y, self._mo, self._d = y, mo, d
        self._h, self._mi, self._s = h, mi, s

    def AddSeconds(self, seconds):
        return _FakeDT(self._y, self._mo, self._d, self._h, self._mi,
                       self._s + int(seconds))

    def ToString(self, fmt):
        if fmt == "MM-dd-yyyy":
            return "%02d-%02d-%04d" % (self._mo, self._d, self._y)
        if fmt == "HH:mm:ss":
            return "%02d:%02d:%02d" % (self._h, self._mi, self._s)
        if fmt == "MM/dd/yyyy":
            return "%02d/%02d/%04d" % (self._mo, self._d, self._y)
        if fmt == "yyMMdd-HHmmss":
            return "%02d%02d%02d-%02d%02d%02d" % (self._y % 100, self._mo, self._d,
                                                  self._h, self._mi, self._s)
        return ""


class _FakeDTClass(object):
    """Replacement for System.DateTime; UtcNow is a fixed 2026-01-02 03:04:05."""


# The application reads `DateTime.UtcNow` and `DateTime.Now` as .NET properties
# (no parentheses), so expose both as plain attributes holding a fixed instance.
# A @staticmethod would stay a function object here and fail with
# "'function' object has no attribute 'AddSeconds'".
_FakeDTClass.UtcNow = _FakeDT(2026, 1, 2, 3, 4, 5)
_FakeDTClass.Now = _FakeDT(2026, 1, 2, 3, 4, 5)


# The default filter bars used by the app (ssp_config.DEFAULT_CONFIG)
_DEFAULT_BARS = [
    ['U', 'B', 'V', 'R', 'I', 'Dark'],
    ['u', 'g', 'r', 'i', 'z', 'Y'],
    ['f13', 'f14', 'f15', 'f16', 'f17', 'f18'],
]

class _SeqWindow(object):
    """Fake window holding the state take_reading/_collect_counts touch."""

    def __init__(self, comm=None, config=None):
        self._closing = False
        self._sequence_abort = False
        self._trial_busy = False
        self.comm = comm if comm is not None else _FakeComm()
        self.config = config if config is not None else _FakeConfig({'auto_manual': 'M'})
        self.statuses = []
        self.saved_data = []
        self.saved_data_tab = []
        self.data_array = []
        self.data_listbox = _FakeDataListBox()
        self._mem_reading_count = 0
        self.mem_calls = []

    def _update_status(self, message):
        self.statuses.append(message)

    def _print_memory_stats(self, reading_num):
        self.mem_calls.append(reading_num)


def _make_window(comm=None, config=None):
    """A _SeqWindow with the REAL SSPDataAcquisitionWindow methods bound."""
    import ssp_dataaq
    W = ssp_dataaq.SSPDataAcquisitionWindow
    w = _SeqWindow(comm, config)
    w.take_reading = lambda *a, **k: W.take_reading(w, *a, **k)
    w._collect_counts = lambda *a, **k: W._collect_counts(w, *a, **k)
    w._filter_position_for_name = lambda *a, **k: W._filter_position_for_name(w, *a, **k)
    w._format_data_line = lambda *a, **k: W._format_data_line(w, *a, **k)
    w._format_data_line_tab = lambda *a, **k: W._format_data_line_tab(w, *a, **k)
    return w


def _with_fake_datetime(fn):
    """Run fn() with ssp_dataaq.DateTime replaced by the fixed shim."""
    import ssp_dataaq
    real = ssp_dataaq.DateTime
    ssp_dataaq.DateTime = _FakeDTClass
    try:
        return fn()
    finally:
        ssp_dataaq.DateTime = real


def _has_take_reading():
    try:
        import ssp_dataaq  # noqa: F401
    except Exception as e:
        print("  ⚠ ssp_dataaq import skipped (standalone): " + str(e))
        return None
    if not (hasattr(ssp_dataaq.SSPDataAcquisitionWindow, 'take_reading') and
            hasattr(ssp_dataaq.SSPDataAcquisitionWindow, '_collect_counts') and
            hasattr(ssp_dataaq.SSPDataAcquisitionWindow, '_filter_position_for_name')):
        print("  ✗ SSPDataAcquisitionWindow is missing the Phase 1 methods")
        _print_stale_module_hint('ssp_dataaq', ssp_dataaq)
        return 'missing'
    return ssp_dataaq


# --- Test 1: take_reading parity with _on_start -------------------------------

def test_take_reading_parity():
    print("\nTesting take_reading records a line (parity with _on_start)...")
    if _has_take_reading() is None:
        return True                      # skipped (standalone)

    # interval=3, integ=5.0 s, no binning -> mid = start + int(3*5*1/2) = +7 s
    expected = ("01-02-2026 03:04:12 V    V PER          V  "
                "00496  00497  00498          5 10")

    def run():
        comm = _FakeComm(counts=["00496", "00497", "00498"])
        w = _make_window(comm, _FakeConfig({'auto_manual': 'M'}))
        result = w.take_reading("V PER", "V", "V", 10, 5.0, 3, "slow", headless=True)
        return (w, comm, result)

    w, comm, result = _with_fake_datetime(run)

    ok = True
    if result != (True, expected):
        print("  ✗ returned %r" % (result,))
        print("       expected (True, %r)" % (expected,))
        ok = False
    else:
        print("  ✓ returned the exact expected data line")

    if w.saved_data != [expected]:
        print("  ✗ saved_data = %r" % (w.saved_data,))
        ok = False
    else:
        print("  ✓ saved_data holds the line")

    if len(w.saved_data_tab) != 1:
        print("  ✗ saved_data_tab has %d entries" % len(w.saved_data_tab))
        ok = False
    else:
        print("  ✓ saved_data_tab holds one entry")

    if w.data_array != [expected]:
        print("  ✗ data_array = %r" % (w.data_array,))
        ok = False
    else:
        print("  ✓ data_array[0] is the line (reverse display)")

    if w.data_listbox.Items.store != [expected]:
        print("  ✗ listbox items = %r" % (w.data_listbox.Items.store,))
        ok = False
    else:
        print("  ✓ data_listbox got the line")

    # SSP parameter sync (integration in ms, gain, no filter move in manual mode)
    if comm.integration_calls == [5000] and comm.gain_calls == [10] and \
            comm.filter_calls == []:
        print("  ✓ set_integration(5000) + set_gain(10); no filter move (manual)")
    else:
        print("  ✗ SSP calls wrong: integ=%s gain=%s filter=%s"
              % (comm.integration_calls, comm.gain_calls, comm.filter_calls))
        ok = False

    if "Getting count data for V filter - please wait" in w.statuses and \
            "Data collection complete - 3 readings." in w.statuses:
        print("  ✓ status messages match the original")
    else:
        print("  ✗ status messages wrong: %s" % (w.statuses,))
        ok = False

    if w._mem_reading_count == 1 and w.mem_calls == [1]:
        print("  ✓ memory-stats hook fired once")
    else:
        print("  ✗ memory-stats hook wrong: count=%s calls=%s"
              % (w._mem_reading_count, w.mem_calls))
        ok = False

    return ok

# --- Test 1b: gain type coercion ---------------------------------------------

def test_take_reading_gain_coercion():
    print("\nTesting take_reading coerces a string gain to int...")
    if _has_take_reading() is None:
        return True
    comm = _FakeComm(counts=["00496"])
    w = _make_window(comm, _FakeConfig({'auto_manual': 'M'}))
    res = _with_fake_datetime(lambda: w.take_reading(
        "V PER", "V", "V", "10", 5.0, 1, "slow", headless=True))
    if comm.gain_calls == [10] and res[0] is True:
        print("  ✓ string gain '10' -> comm.set_gain(int 10)")
        return True
    print("  ✗ gain_calls = %r (expected [10])" % (comm.gain_calls,))
    return False


# --- Test 2: guards ----------------------------------------------------------

def test_take_reading_guards():
    print("\nTesting take_reading / _collect_counts guards...")
    if _has_take_reading() is None:
        return True

    ok = True

    # 1. _closing=True -> bail before any SSP call
    comm = _FakeComm(counts=["00496"])
    w = _make_window(comm, _FakeConfig({'auto_manual': 'M'}))
    w._closing = True
    r = w.take_reading("V PER", "V", "V", 10, 5.0, 3, "slow", headless=True)
    if r == (False, None) and w.saved_data == [] and comm.integration_calls == []:
        print("  ✓ _closing -> no reading, no SSP calls")
    else:
        print("  ✗ _closing guard wrong: r=%r saved=%r integ=%r"
              % (r, w.saved_data, comm.integration_calls))
        ok = False

    # 2. _sequence_abort=True -> bail before any SSP call
    comm = _FakeComm(counts=["00496"])
    w = _make_window(comm, _FakeConfig({'auto_manual': 'M'}))
    w._sequence_abort = True
    r = w.take_reading("V PER", "V", "V", 10, 5.0, 3, "slow", headless=True)
    if r == (False, None) and w.saved_data == [] and comm.integration_calls == []:
        print("  ✓ _sequence_abort -> no reading, no SSP calls")
    else:
        print("  ✗ _sequence_abort guard wrong: r=%r saved=%r integ=%r"
              % (r, w.saved_data, comm.integration_calls))
        ok = False

    # 3. _collect_counts aborts mid-loop when a count sets _sequence_abort
    comm = _FakeComm(counts=["00010", "00020", "00030"])
    w = _make_window(comm, _FakeConfig())

    def _flip(c, count_no):
        w._sequence_abort = True
    comm.on_count = _flip
    result = w._collect_counts(5.0, 3, 5000)
    if result == (None, 1):
        print("  ✓ _collect_counts returns (None, 1) after a mid-loop abort")
    else:
        print("  ✗ mid-loop abort wrong: %r" % (result,))
        ok = False

    # 4. Mid-loop abort with interval=6 must NOT bin (no IndexError on short list)
    comm = _FakeComm(counts=["00010", "00020", "00030", "00040", "00050", "00060"])
    w = _make_window(comm, _FakeConfig())

    def _flip2(c, count_no):
        if count_no >= 2:
            w._sequence_abort = True
    comm.on_count = _flip2
    result = w._collect_counts(5.0, 6, 5000)
    if result == (None, 1):
        print("  ✓ interval=6 mid-loop abort returns (None, 1), no IndexError")
    else:
        print("  ✗ interval=6 mid-loop abort wrong: %r" % (result,))
        ok = False

    return ok

# --- Test 3: binning + retry -------------------------------------------------

def test_collect_counts_binning():
    print("\nTesting 6/8 interval binning + retry/zero fallback...")
    if _has_take_reading() is None:
        return True

    ok = True

    w = _make_window(_FakeComm(counts=["00496", "00497", "00498"]), _FakeConfig())
    counts, binning = w._collect_counts(5.0, 3, 5000)
    if (counts, binning) == (["00496", "00497", "00498"], 1):
        print("  ✓ interval=3 -> binning 1, counts unchanged")
    else:
        print("  ✗ interval=3 wrong: %r, %r" % (counts, binning))
        ok = False

    w = _make_window(_FakeComm(counts=["00010", "00020", "00030",
                                       "00040", "00050", "00060"]), _FakeConfig())
    counts, binning = w._collect_counts(5.0, 6, 5000)
    if (counts, binning) == (["30", "70", "110"], 2):
        print("  ✓ interval=6 -> binning 2, pairs summed to 3 readings")
    else:
        print("  ✗ interval=6 wrong: %r, %r" % (counts, binning))
        ok = False

    w = _make_window(_FakeComm(counts=["00100", "00200", "00300", "00400",
                                       "00500", "00600", "00700", "00800"]),
                     _FakeConfig())
    counts, binning = w._collect_counts(5.0, 8, 5000)
    if (counts, binning) == (["300", "700", "1100", "1500"], 2):
        print("  ✓ interval=8 -> binning 2, pairs summed to 4 readings")
    else:
        print("  ✗ interval=8 wrong: %r, %r" % (counts, binning))
        ok = False

    # Retry: first read fails, retry succeeds
    w = _make_window(_FakeComm(counts=["00496", "00497"], fail_first_n=1), _FakeConfig())
    counts, binning = w._collect_counts(5.0, 2, 5000)
    if (counts, binning) == (["00496", "00497"], 1):
        print("  ✓ first-read failure is retried and recovers")
    else:
        print("  ✗ retry path wrong: %r, %r" % (counts, binning))
        ok = False

    # Persistent failure -> "00000" placeholders
    w = _make_window(_FakeComm(always_fail=True), _FakeConfig())
    counts, binning = w._collect_counts(5.0, 2, 5000)
    if (counts, binning) == (["00000", "00000"], 1):
        print("  ✓ persistent failure inserts 00000 placeholders")
    else:
        print("  ✗ failure fallback wrong: %r, %r" % (counts, binning))
        ok = False

    # End-to-end: take_reading with interval=6 (binned; integration label doubled)
    def run6():
        comm = _FakeComm(counts=["00010", "00020", "00030", "00040", "00050", "00060"])
        w = _make_window(comm, _FakeConfig({'auto_manual': 'M'}))
        return w.take_reading("V PER", "V", "V", 10, 5.0, 6, "slow", headless=True)

    expected6 = "01-02-2026 03:04:20 V    V PER          V     30     70    110         10 10"
    r6 = _with_fake_datetime(run6)
    if r6 == (True, expected6):
        print("  ✓ take_reading interval=6 line (binned, integration doubled)")
    else:
        print("  ✗ take_reading interval=6 line wrong: %r" % (r6,))
        ok = False

    # End-to-end: SKY reading uses a blank catalog code
    def runsky():
        comm = _FakeComm(counts=["00052"])
        w = _make_window(comm, _FakeConfig({'auto_manual': 'M'}))
        return w.take_reading("SKYLAST", " ", "V", 10, 5.0, 1, "slow", headless=True)

    expected_sky = "01-02-2026 03:04:07      SKYLAST        V  00052                        5 10"
    rsky = _with_fake_datetime(runsky)
    if rsky == (True, expected_sky):
        print("  ✓ SKYLAST reading line (blank catalog code)")
    else:
        print("  ✗ SKYLAST line wrong: %r" % (rsky,))
        ok = False

    return ok

# --- Test 4: filter position mapping -----------------------------------------

def test_filter_position_for_name():
    print("\nTesting _filter_position_for_name (active bar mapping)...")
    if _has_take_reading() is None:
        return True

    ok = True

    cfg1 = _FakeConfig({'active_filter_bar': 1, 'filter_bars': _DEFAULT_BARS})
    w = _make_window(_FakeComm(), cfg1)
    for name, expected in [('U', 1), ('V', 3), ('Dark', 6),
                           ('Home', None), ('zzz', None), ('', None)]:
        got = w._filter_position_for_name(name)
        if got != expected:
            print("  ✗ bar1 %r -> %r, expected %r" % (name, got, expected))
            ok = False
    if ok:
        print("  ✓ bar 1: U->1, V->3, Dark->6, Home/zzz/''->None")

    cfg2 = _FakeConfig({'active_filter_bar': 2, 'filter_bars': _DEFAULT_BARS})
    w2 = _make_window(_FakeComm(), cfg2)
    if w2._filter_position_for_name('g') == 2 and w2._filter_position_for_name('Y') == 6:
        print("  ✓ bar 2: g->2, Y->6")
    else:
        print("  ✗ bar 2 mapping wrong: g=%r Y=%r"
              % (w2._filter_position_for_name('g'), w2._filter_position_for_name('Y')))
        ok = False

    # Auto mode: take_reading moves the bar to the mapped position
    cfg3 = _FakeConfig({'auto_manual': 'A', 'active_filter_bar': 1,
                        'filter_bars': _DEFAULT_BARS})
    comm = _FakeComm(counts=["00496"], select_filter_result=(True, 0, "ok"))
    w3 = _make_window(comm, cfg3)

    def run_auto():
        return w3.take_reading("V PER", "V", "B", 10, 5.0, 1, "slow", headless=True)

    _with_fake_datetime(run_auto)
    if comm.filter_calls == [2]:
        print("  ✓ auto mode moved the bar to B (position 2)")
    else:
        print("  ✗ auto filter move wrong: %s" % (comm.filter_calls,))
        ok = False

    return ok


# --- Executor tests (Phase 2: sequence engine) -------------------------------

class _ExecStar(object):
    """Minimal StarData stand-in for executor tests."""

    def __init__(self, name, ra_h, dec):
        self.name = name
        self.ra_hours = int(ra_h)
        self.ra_minutes = int((ra_h - int(ra_h)) * 60)
        self.ra_seconds = 0.0
        self.dec_degrees = int(dec)
        self.dec_minutes = 0
        self.dec_seconds = 0.0

    @property
    def dec_degrees_decimal(self):
        return float(self.dec_degrees)


class _ExecItems(object):
    def __init__(self, items=None):
        self._items = list(items or [])

    @property
    def Count(self):
        return len(self._items)

    def __getitem__(self, i):
        return self._items[i]


class _ExecCombo(object):
    def __init__(self, items=None, text=""):
        self.Items = _ExecItems(items)
        self.Text = text
        self.SelectedIndex = 0


class _ExecTriple(object):
    def __init__(self, v, c=None, k=None):
        self.variable = v
        self.comparison = c
        self.check = k


class _ExecWindow(object):
    """Fake window for the executor; real methods are bound by _make_exec_window."""

    def __init__(self):
        self._closing = False
        self._sequence_abort = False
        self._sequence_running = False
        self._sequence_paused = False
        self._sequence = None
        self._sequence_obs_count = 0
        self._sequence_start = None
        self._sequence_step_index = 0
        self._sequence_steps_total = 0
        self.sharpcap_available = True
        self.current_target = None
        self.catalog = None
        self.comm = _FakeComm([])
        self.config = _FakeConfig({'auto_manual': 'M'})
        self.object_combo = _ExecCombo(text='V PER')
        self.catalog_combo = _ExecCombo(text='Var')
        self.filter_combo = _ExecCombo(items=['U', 'B', 'V', 'R', 'I', 'Dark', 'Home'],
                                       text='V')
        self.gain_combo = _ExecCombo(text='10')
        self.integ_combo = _ExecCombo(text='5.00')
        self.interval_combo = _ExecCombo(text='3')
        self.mode_combo = _ExecCombo(text='slow')
        self.updating_filter_combo = False
        self.calls = []
        self.statuses = []

    def _update_status(self, m):
        self.statuses.append(m)

    def take_reading(self, o, c, f, gv, i, iv, m, append=True, headless=False):
        self.calls.append(('measure', o, c, f, headless))
        return (True, 'LINE')

    def _slew_to_star(self, star, label, headless=False, plate_solve=None):
        self.calls.append(('slew', star.name, label, headless, plate_solve))
        return True

    def _star_display_name(self, ref):
        return {'V': 'VAR', 'C': 'COMP', 'K': 'CHK'}.get(ref, ref)

    def _select_object_display(self, name):
        self.calls.append(('select', name))

    def _apply_target(self, target):
        # Stub for the sequence TARGET step. The real window also rebuilds the
        # Object dropdown / target label; the tests only need the state change
        # and a record of the call.
        self.current_target = target
        self.calls.append(('apply_target', getattr(target, 'variable', None)))

    def _select_filter_by_name(self, name):
        self.calls.append(('filter', name))

    def _filter_position_for_name(self, name):
        return None

    def _set_sequence_controls_running(self, running):
        pass


class _FakeCatalog(object):
    """Minimal StarCatalog stand-in for TARGET resolution tests."""

    def __init__(self, targets=None):
        self.targets = list(targets or [])

    def get_count(self):
        return len(self.targets)

    def get_target_by_name(self, name):
        key = str(name).upper().strip()
        for t in self.targets:
            if t.variable.name.upper() == key:
                return t
        return None

    def get_target_by_auid(self, auid):
        key = str(auid).upper().strip()
        for t in self.targets:
            if getattr(t, 'auid', '').upper() == key:
                return t
        return None


_EXEC_METHODS = ('run_sequence', '_sequence_should_stop', '_sequence_wait_if_paused',
                 '_run_step_list',
                 '_find_matching_end', '_step_goto', '_step_target', '_step_measure', '_step_sky',
                 '_step_filter', '_step_wait', '_step_wait_until', '_step_abort_if',
                 '_resolve_step_star', '_make_offset_star', '_offset_star',
                 '_make_star_from_radec',
                 '_current_alt_airmass', '_parse_utc_datetime', '_update_step_status')


def _make_exec_window():
    """A _ExecWindow with the REAL executor methods from ssp_dataaq bound."""
    import ssp_dataaq
    W = ssp_dataaq.SSPDataAcquisitionWindow
    w = _ExecWindow()
    for name in _EXEC_METHODS:
        func = getattr(W, name)
        setattr(w, name, lambda *a, _f=func, **k: _f(w, *a, **k))
    return w


def _has_engine():
    """Return the ssp_dataaq module if the executor exists, else None/'missing'."""
    try:
        import ssp_dataaq
    except Exception as e:
        print("  ⚠ ssp_dataaq import skipped (standalone): " + str(e))
        return None
    if not hasattr(ssp_dataaq.SSPDataAcquisitionWindow, 'run_sequence'):
        print("  ✗ SSPDataAcquisitionWindow is missing 'run_sequence'")
        _print_stale_module_hint('ssp_dataaq', ssp_dataaq)
        return 'missing'
    return ssp_dataaq


# --- Test 4: executor ordering -----------------------------------------------

def test_executor_order():
    print("\nTesting executor runs steps in order...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ ssp_sequence import skipped: " + str(e))
        return True

    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0),
                                   _ExecStar('COMP', 12.5, 30.5))
    seq = ssp_sequence.build_templates()['V-C-V-C']
    seq.max_observations = 8
    w.run_sequence(seq)

    meas_calls = [c for c in w.calls if c[0] == 'measure']
    meas = len(meas_calls)
    slews = [c for c in w.calls if c[0] == 'slew']
    ok = True
    if meas == 8:
        print("  ✓ 2 passes produced 8 measures")
    else:
        print("  ✗ measures = %d, expected 8" % meas)
        ok = False
    if meas_calls and all(c[4] is True for c in meas_calls):
        print("  ✓ measurements ran headless (no modal)")
    else:
        print("  ✗ measurements not headless: %s" % (meas_calls[:2],))
        ok = False
    if len(slews) == 8 and all(c[3] is True for c in slews):
        print("  ✓ 8 headless slews")
    else:
        print("  ✗ slews wrong: %s" % (slews,))
        ok = False
    order = [c[1] for c in slews][:4]
    if order == ['VAR', 'COMP', 'VAR', 'COMP']:
        print("  ✓ V-C-V-C slew order")
    else:
        print("  ✗ slew order %s" % order)
        ok = False
    if w._sequence_running is False:
        print("  ✓ engine unlocked after the run")
    else:
        print("  ✗ still marked running")
        ok = False
    return ok

# --- Test 5: stop conditions -------------------------------------------------

def test_executor_stop_conditions():
    print("\nTesting executor stop conditions (obs / minutes / abort)...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
        from System import DateTime as SDateTime
    except Exception as e:
        print("  ⚠ imports skipped: " + str(e))
        return True

    ok = True

    # max_observations
    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    seq = ssp_sequence.build_templates()['V-C-V-C']
    seq.max_observations = 4
    w.run_sequence(seq)
    meas = len([c for c in w.calls if c[0] == 'measure'])
    if meas == 4:
        print("  ✓ max_observations=4 stopped after 4")
    else:
        print("  ✗ max_observations gave %d" % meas)
        ok = False

    # max_minutes: set the start relative to the real clock (no module patching,
    # so the app's 1 s time-display timer keeps working)
    ws = _make_exec_window()
    seqm = ssp_sequence.PEPSequence()
    seqm.max_minutes = 60
    ws._sequence_start = SDateTime.UtcNow.AddMinutes(-30)
    early = ws._sequence_should_stop(seqm)
    ws._sequence_start = SDateTime.UtcNow.AddMinutes(-61)
    late = ws._sequence_should_stop(seqm)
    if early is False and late is True:
        print("  ✓ max_minutes: not stopped at 30, stopped at 61")
    else:
        print("  ✗ max_minutes wrong: early=%s late=%s" % (early, late))
        ok = False

    # mid-run abort
    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    n = [0]

    def _tr(*a, **k):
        n[0] += 1
        if n[0] >= 2:
            w._sequence_abort = True
        w.calls.append(('measure',))
        return (True, 'L')

    w.take_reading = _tr
    seq2 = ssp_sequence.build_templates()['V-C-V-C']
    seq2.max_observations = 8
    w.run_sequence(seq2)
    if n[0] == 2:
        print("  ✓ abort stopped the run after 2 measures")
    else:
        print("  ✗ abort wrong: %d measures" % n[0])
        ok = False

    return ok


# --- Test 6: REPEAT nesting --------------------------------------------------

def test_executor_repeat():
    print("\nTesting executor REPEAT nesting...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    seq = ssp_sequence.parse_ssp_text("REPEAT, 3\nGOTO, V\nMEASURE\nEND\n")
    seq.repeat = 1
    w.run_sequence(seq)
    meas = len([c for c in w.calls if c[0] == 'measure'])
    if meas == 3:
        print("  ✓ REPEAT,3 -> 3 measures")
        return True
    print("  ✗ REPEAT gave %d" % meas)
    return False


# --- Test 6b: pause hold between steps ---------------------------------------

def test_executor_pause():
    print("\nTesting executor pause hold (between steps)...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    ok = True

    # Not paused -> the gate returns True immediately (no hold)
    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    if w._sequence_wait_if_paused() is True:
        print("  ✓ not paused -> gate returns True")
    else:
        print("  ✗ not-paused gate should return True")
        ok = False

    # Paused + STOP -> the gate returns False so the run ends
    w2 = _make_exec_window()
    w2._sequence_paused = True
    w2._sequence_abort = True
    if w2._sequence_wait_if_paused() is False:
        print("  ✓ paused + STOP -> gate returns False (run ends)")
    else:
        print("  ✗ paused+abort gate should return False")
        ok = False

    # The gate is checked before every step (pause takes effect between steps)
    w3 = _make_exec_window()
    w3.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    calls = []
    w3._sequence_wait_if_paused = lambda: (calls.append(1), True)[1]
    seq = ssp_sequence.parse_ssp_text(
        "GOTO, V\nMEASURE\nGOTO, C\nMEASURE\n")
    seq.repeat = 1
    w3.run_sequence(seq)
    if len(calls) == 4:
        print("  ✓ pause gate checked before each of the 4 steps")
    else:
        print("  ✗ pause gate calls: %d (expected 4)" % len(calls))
        ok = False
    return ok


# --- Test 7: star resolution -------------------------------------------------

def test_executor_resolve_star():
    print("\nTesting executor star resolution...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0),
                                   _ExecStar('COMP', 12.5, 30.5), None)
    ok = True
    s, _lab = w._resolve_step_star(ssp_sequence.SequenceStep('GOTO', star_ref='V'))
    if s is not None and s.name == 'VAR':
        print("  ✓ V -> variable")
    else:
        print("  ✗ V resolve failed")
        ok = False
    s, _lab = w._resolve_step_star(ssp_sequence.SequenceStep('GOTO', star_ref='C'))
    if s is not None and s.name == 'COMP':
        print("  ✓ C -> comparison")
    else:
        print("  ✗ C resolve failed")
        ok = False
    s, _lab = w._resolve_step_star(ssp_sequence.SequenceStep('GOTO', star_ref='K'))
    if s is None:
        print("  ✓ missing K -> None (step skipped)")
    else:
        print("  ✗ K should be None")
        ok = False

    # V + RA/Dec offset -> the variable star shifted by the offset
    s, _lab = w._resolve_step_star(ssp_sequence.SequenceStep(
        'GOTO', star_ref='V', d_ra_h=0.5, d_dec_deg=0.25))
    if s is not None:
        rh = s.ra_hours + s.ra_minutes / 60.0 + s.ra_seconds / 3600.0
        if abs(rh - 12.5) < 1e-6 and abs(s.dec_degrees_decimal - 30.25) < 1e-6:
            print("  ✓ V + offset -> variable star shifted by the offset")
        else:
            print("  ✗ V+offset wrong: RA=%s Dec=%s"
                  % (rh, s.dec_degrees_decimal))
            ok = False
    else:
        print("  ✗ V+offset resolve failed")
        ok = False
    return ok


# --- Test 8: offset / RA-Dec math --------------------------------------------

def test_executor_offset_math():
    print("\nTesting executor offset / RA-Dec math...")
    if _has_engine() is None:
        return True
    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    ok = True
    off = w._make_offset_star(0.5, 0.25)
    rh = off.ra_hours + off.ra_minutes / 60.0 + off.ra_seconds / 3600.0
    if abs(rh - 12.5) < 1e-6 and abs(off.dec_degrees_decimal - 30.25) < 1e-6:
        print("  ✓ offset (+0.5h, +0.25deg)")
    else:
        print("  ✗ offset wrong: RA=%s Dec=%s" % (rh, off.dec_degrees_decimal))
        ok = False
    ab = w._make_star_from_radec(23.9, -10.0)
    rh2 = ab.ra_hours + ab.ra_minutes / 60.0 + ab.ra_seconds / 3600.0
    if abs(rh2 - 23.9) < 1e-6 and abs(ab.dec_degrees_decimal + 10.0) < 1e-6:
        print("  ✓ absolute RA/Dec")
    else:
        print("  ✗ radec wrong: RA=%s Dec=%s" % (rh2, ab.dec_degrees_decimal))
        ok = False
    return ok

# --- Test 9: sky reading -----------------------------------------------------

def test_executor_sky():
    print("\nTesting executor sky reading (blank catalog)...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    w = _make_exec_window()
    w._step_sky(ssp_sequence.SequenceStep('SKY', label='SKYLAST'))
    last = w.calls[-1]
    if last[0] == 'measure' and last[1] == 'SKYLAST' and last[2] == ' ':
        print("  ✓ SKYLAST measured with blank catalog code")
        return True
    print("  ✗ sky call wrong: %s" % (last,))
    return False


# --- Test 10: standalone GOTO + headless -------------------------------------

def test_executor_goto_standalone():
    print("\nTesting GOTO skip (standalone) and headless slew...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    ok = True
    w = _make_exec_window()
    w.sharpcap_available = False
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    w._step_goto(ssp_sequence.SequenceStep('GOTO', star_ref='V'))
    if not any(c[0] == 'slew' for c in w.calls) and \
            any('standalone' in s for s in w.statuses):
        print("  ✓ standalone GOTO skipped (no slew, status logged)")
    else:
        print("  ✗ standalone GOTO not skipped: %s" % (w.calls,))
        ok = False

    w2 = _make_exec_window()
    w2.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    w2._step_goto(ssp_sequence.SequenceStep('GOTO', star_ref='V'))
    slews = [c for c in w2.calls if c[0] == 'slew']
    if len(slews) == 1 and slews[0][3] is True:
        print("  ✓ SharpCap GOTO slews headless (no modal)")
    else:
        print("  ✗ headless slew wrong: %s" % (slews,))
        ok = False
    return ok


# --- Test 12b: per-step plate-solve override ---------------------------------

def test_executor_plate_solve_override():
    print("\nTesting per-step plate_solve override (GOTO OFFSET / SKY)...")
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    ok = True

    # --- pure ssp_sequence checks (run without SharpCap) ---
    # .ssp text round-trip preserves the flag
    text = ("GOTO, OFFSET,0.0,0.25, plate_solve=0\n"
            "SKY, label=SKYLAST, offset=0.0,0.25, plate_solve=0\n")
    seq = ssp_sequence.parse_ssp_text(text)
    again = ssp_sequence.parse_ssp_text(ssp_sequence.serialize_ssp_text(seq))
    g = again.steps[0]
    s = again.steps[1]
    if g.params.get('plate_solve') == 0 and s.params.get('plate_solve') == 0:
        print("  ✓ .ssp text round-trip keeps plate_solve=0")
    else:
        print("  ✗ round-trip lost flag: GOTO=%r SKY=%r" % (g.params, s.params))
        ok = False

    # Editor fields round-trip (Params box -> step -> Params box)
    step = ssp_sequence.step_from_fields('GOTO', 'OFFSET,0.0,0.25', '',
                                         'plate_solve=0')
    if step.params.get('plate_solve') == 0:
        print("  ✓ editor Params box applies plate_solve=0 to GOTO")
    else:
        print("  ✗ editor Params box dropped flag: %r" % (step.params,))
        ok = False
    _k, _v, _l, ptext = ssp_sequence.fields_from_step(step)
    if 'plate_solve=0' in ptext:
        print("  ✓ editor shows plate_solve in Params box")
    else:
        print("  ✗ editor Params text missing flag: %r" % (ptext,))
        ok = False

    # --- executor propagation (needs ssp_dataaq / SharpCap) ---
    if _has_engine() is None:
        print("  ⚠ executor checks skipped (no ssp_dataaq)")
        return ok

    # GOTO, OFFSET with plate_solve=0 reaches _slew_to_star with the flag
    w = _make_exec_window()
    w.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    w._step_goto(ssp_sequence.SequenceStep('GOTO', star_ref='OFFSET',
                                           d_ra_h=0.0, d_dec_deg=0.25,
                                           plate_solve=0))
    slews = [c for c in w.calls if c[0] == 'slew']
    if len(slews) == 1 and slews[0][4] == 0:
        print("  ✓ GOTO OFFSET forwards plate_solve=0")
    else:
        print("  ✗ GOTO OFFSET flag wrong: %s" % (slews,))
        ok = False

    # SKY with an offset forwards plate_solve=0 to the offset slew
    w2 = _make_exec_window()
    w2.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    w2._step_sky(ssp_sequence.SequenceStep('SKY', label='SKYLAST',
                                           d_ra_h=0.0, d_dec_deg=0.25,
                                           plate_solve=0))
    slews2 = [c for c in w2.calls if c[0] == 'slew']
    if len(slews2) == 1 and slews2[0][4] == 0:
        print("  ✓ SKY offset forwards plate_solve=0")
    else:
        print("  ✗ SKY offset flag wrong: %s" % (slews2,))
        ok = False

    # No flag -> None so the global "Plate Solve and Sync" option decides
    w3 = _make_exec_window()
    w3.current_target = _ExecTriple(_ExecStar('VAR', 12.0, 30.0))
    w3._step_goto(ssp_sequence.SequenceStep('GOTO', star_ref='OFFSET',
                                            d_ra_h=0.0, d_dec_deg=0.25))
    slews3 = [c for c in w3.calls if c[0] == 'slew']
    if len(slews3) == 1 and slews3[0][4] is None:
        print("  ✓ No flag -> plate_solve=None (global option used)")
    else:
        print("  ✗ default flag wrong: %s" % (slews3,))
        ok = False

    return ok


# --- Test 10b: TARGET catalog validation + executor step ---------------------

def test_target_catalog_validation():
    print("\nTesting TARGET catalog validation helpers...")
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    triple = _ExecTriple(_ExecStar('OMI CET', 2.5, 30.0),
                         _ExecStar('OMI CET C', 2.6, 30.1),
                         _ExecStar('OMI CET K', 2.7, 30.2))
    triple.auid = '000-BBW-425'
    cat = _FakeCatalog([triple])

    seq = ssp_sequence.parse_ssp_text(
        "TARGET, OMI CET\nTARGET, auid=000-BBW-425\nTARGET, XXX YYY\n",
        name='t')
    ok = True
    missing = ssp_sequence.missing_catalog_targets(seq, cat)
    if missing != [(3, 'XXX YYY')]:
        print("  ✗ missing_catalog_targets wrong: %r" % (missing,))
        ok = False
    else:
        print("  ✓ name + auid resolve; the unknown object is reported missing")
    if ssp_sequence.missing_catalog_targets(seq, None) is not None:
        print("  ✗ no catalog should return None")
        ok = False
    else:
        print("  ✓ missing catalog -> None (caller shows a single note)")
    if ssp_sequence.resolve_catalog_target(cat, 'omi cet').variable.name != 'OMI CET':
        print("  ✗ case-insensitive name resolution failed")
        ok = False
    if ssp_sequence.resolve_catalog_target(cat, 'XXX YYY') is not None:
        print("  ✗ unknown object should resolve to None")
        ok = False
    flagseq = ssp_sequence.parse_ssp_text("TARGET, 000-BBW-425, id=auid\n",
                                          name='t')
    if flagseq.steps[0].params != {'object': '000-BBW-425', 'id_type': 'auid'}:
        print("  ✗ trailing ', id=auid' form not parsed: %r"
              % (flagseq.steps[0].params,))
        ok = False
    else:
        print("  ✓ trailing ', id=auid' form parsed")
    return ok


def test_executor_target():
    print("\nTesting executor TARGET step (catalog object load)...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    triple = _ExecTriple(_ExecStar('OMI CET', 2.5, 30.0),
                         _ExecStar('OMI CET C', 2.6, 30.1),
                         _ExecStar('OMI CET K', 2.7, 30.2))
    triple.auid = '000-BBW-425'
    cat = _FakeCatalog([triple])
    ok = True

    # Resolve by name -> the target is applied
    w = _make_exec_window()
    w.catalog = cat
    w._step_target(ssp_sequence.SequenceStep('TARGET', object='omi cet',
                                             id_type=None))
    applied = [c for c in w.calls if c[0] == 'apply_target']
    if w.current_target is triple and applied:
        print("  ✓ TARGET by name loads the target triple")
    else:
        print("  ✗ TARGET by name failed: %r" % (w.current_target,))
        ok = False

    # Resolve by AUID
    w2 = _make_exec_window()
    w2.catalog = cat
    w2._step_target(ssp_sequence.SequenceStep('TARGET', object='000-BBW-425',
                                              id_type='auid'))
    if w2.current_target is triple:
        print("  ✓ TARGET by AUID loads the target triple")
    else:
        print("  ✗ TARGET by AUID failed")
        ok = False

    # Unknown object -> silent skip (no apply, no exception, status noted)
    w3 = _make_exec_window()
    w3.catalog = cat
    w3._step_target(ssp_sequence.SequenceStep('TARGET', object='NOPE',
                                              id_type=None))
    applied3 = [c for c in w3.calls if c[0] == 'apply_target']
    if w3.current_target is None and not applied3:
        print("  ✓ unknown TARGET is skipped silently")
    else:
        print("  ✗ unknown TARGET should have been skipped")
        ok = False
    return ok


# --- Test 11: .ssp text round-trip -------------------------------------------

def test_ssp_text_roundtrip():
    print("\nTesting .ssp text parse / serialize round-trip...")
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    text = ("MAXMINUTES, 60\nREPEAT, 2\n  GOTO, C\n"
            "  TARGET, OMI CET\n"
            "  MEASURE, filter=V, integ=5, interval=3\n"
            "  GOTO, V\n  SKY, label=SKYLAST, offset=0.0,0.25\nEND\n")
    seq = ssp_sequence.parse_ssp_text(text, name='t')
    expected = ['REPEAT', 'GOTO', 'TARGET', 'MEASURE', 'GOTO', 'SKY', 'END']
    if [s.kind for s in seq.steps] != expected:
        print("  ✗ parsed kinds %s" % [s.kind for s in seq.steps])
        return False
    print("  ✓ parsed kinds %s" % expected)
    seq2 = ssp_sequence.parse_ssp_text(ssp_sequence.serialize_ssp_text(seq), name='t')
    if [s.kind for s in seq2.steps] != expected:
        print("  ✗ round-trip kinds %s" % [s.kind for s in seq2.steps])
        return False
    print("  ✓ serialize / parse round-trip")
    tstep = [s for s in seq2.steps if s.kind == 'TARGET'][0]
    if tstep.params.get('object') != 'OMI CET':
        print("  ✗ TARGET object lost: %r" % tstep.params)
        return False
    auid = ssp_sequence.parse_ssp_text("TARGET, auid=000-BBW-425\n", name='t')
    if auid.steps[0].params != {'object': '000-BBW-425', 'id_type': 'auid'}:
        print("  ✗ auid= prefix not parsed: %r" % auid.steps[0].params)
        return False
    print("  ✓ TARGET identifier (name + auid=) round-trips")
    return True


# --- Test 12: WAIT_UNTIL ------------------------------------------------------

def test_executor_wait_until():
    print("\nTesting WAIT_UNTIL parse + late handling...")
    if _has_engine() is None:
        return True
    try:
        import ssp_sequence
        from System import DateTime as SDateTime
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    ok = True
    w = _make_exec_window()
    if w._parse_utc_datetime('2026-11-27 02:45:00') is not None:
        print("  ✓ parsed a UTC date/time")
    else:
        print("  ✗ parse failed")
        ok = False
    if w._parse_utc_datetime('bogus') is None:
        print("  ✓ invalid date/time -> None")
    else:
        print("  ✗ bogus parsed")
        ok = False

    # Late handling relative to the real clock (no module patching, so the app's
    # 1 s time-display timer keeps working and _parse_utc_datetime stays valid).
    now = SDateTime.UtcNow
    txt_proceed = now.AddMinutes(-10).ToString("yyyy-MM-dd HH:mm:ss")
    txt_stop = now.AddMinutes(-60).ToString("yyyy-MM-dd HH:mm:ss")
    wl = _make_exec_window()
    wl._step_wait_until(ssp_sequence.SequenceStep(
        'WAIT_UNTIL', utc_datetime=txt_proceed))     # 10 min late -> proceed
    late_flag = wl._sequence_abort
    w2 = _make_exec_window()
    w2._step_wait_until(ssp_sequence.SequenceStep(
        'WAIT_UNTIL', utc_datetime=txt_stop))        # 60 min late -> stop
    abort_flag = w2._sequence_abort
    if late_flag is False and abort_flag is True:
        print("  ✓ <=30 min late proceeds; >30 min late stops the run")
    else:
        print("  ✗ late handling wrong: late=%s abort=%s" % (late_flag, abort_flag))
        ok = False
    return ok


# --- Test 12c: RA/Dec offset formatting --------------------------------------

def test_coord_formatting():
    print("\nTesting RA/Dec offset formatting (fixed precision)...")
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True
    ok = True
    # _fmt_coord trims the binary float expansion and trailing zeros
    cases = [
        (0.10000000000000001, '0.1'),
        (0.30000000000000004, '0.3'),
        (0.25, '0.25'),
        (0.0, '0'),
        (-0.25, '-0.25'),
        (12.5, '12.5'),
    ]
    for value, expected in cases:
        got = ssp_sequence._fmt_coord(value)
        if got != expected:
            print("  ✗ _fmt_coord(%r) = %r (expected %r)"
                  % (value, got, expected))
            ok = False
    if ok:
        print("  ✓ _fmt_coord trims full-precision floats and trailing zeros")

    # The offset uses one consistent 'offset=dRA,dDec' syntax everywhere.
    step = ssp_sequence.SequenceStep('GOTO', star_ref='OFFSET',
                                     d_ra_h=0.30000000000000004,
                                     d_dec_deg=0.25)
    if ssp_sequence._step_to_text(step) != 'GOTO, offset=0.3,0.25':
        print("  ✗ GOTO offset-only text: %r" % ssp_sequence._step_to_text(step))
        ok = False
    star = ssp_sequence.SequenceStep('GOTO', star_ref='V',
                                     d_ra_h=0.30000000000000004, d_dec_deg=0.25)
    fields = ssp_sequence.fields_from_step(star)
    if fields[1] != 'V' or fields[3] != 'offset=0.3,0.25':
        print("  ✗ GOTO V+offset fields: %r" % (fields,))
        ok = False
    if ssp_sequence._step_to_text(star) != 'GOTO, V, offset=0.3,0.25':
        print("  ✗ GOTO V+offset text: %r" % ssp_sequence._step_to_text(star))
        ok = False
    # SKY uses the identical offset syntax (text and editor Params)
    sky = ssp_sequence.SequenceStep('SKY', label='SKYLAST',
                                    d_ra_h=0.30000000000000004, d_dec_deg=0.25)
    if ssp_sequence._step_to_text(sky) != 'SKY, label=SKYLAST, offset=0.3,0.25':
        print("  ✗ SKY offset text: %r" % ssp_sequence._step_to_text(sky))
        ok = False
    if ssp_sequence.fields_from_step(sky)[3] != 'offset=0.3,0.25':
        print("  ✗ SKY offset fields: %r" % (ssp_sequence.fields_from_step(sky),))
        ok = False
    if ok:
        print("  ✓ offsets use one 'offset=dRA,dDec' syntax (GOTO + SKY)")
    return ok


# --- Test 12d: GOTO OFFSET entered in the Params box -------------------------

def test_goto_offset_from_params():
    print("\nTesting GOTO OFFSET entered in the Params box...")
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True
    ok = True

    # Value (V/C/K) AND the Params offset are BOTH respected (star + offset)
    star_cases = [('V', 'OFFSET,0.0,0.25', 'V'),
                  ('C', 'offset=0.1,0.2', 'C'),
                  ('K', 'OFFSET,0.5,0.25', 'K')]
    for value, params, expect_ref in star_cases:
        step = ssp_sequence.step_from_fields('GOTO', value, '', params)
        if (step.params.get('star_ref') != expect_ref
                or step.params.get('d_ra_h') is None
                or step.params.get('d_dec_deg') is None):
            print("  ✗ %s + %s -> %r" % (value, params, step.params))
            ok = False
    if ok:
        print("  ✓ Value (V/C/K) + Params offset both applied (star + offset)")

    # blank Value + Params offset -> offset from the current target's variable
    step = ssp_sequence.step_from_fields('GOTO', '', '', 'OFFSET,0.0,0.25')
    if step.params.get('star_ref') != 'OFFSET':
        print("  ✗ blank Value + offset -> %r" % (step.params,))
        ok = False
    else:
        print("  ✓ blank Value + Params offset -> OFFSET from the target")

    # absolute coords + Params offset
    step = ssp_sequence.step_from_fields('GOTO', '12.5,-30.25', '',
                                         'OFFSET,0.0,0.25')
    if (step.params.get('ra') != 12.5 or step.params.get('dec') != -30.25
            or step.params.get('d_dec_deg') is None):
        print("  ✗ coords + offset -> %r" % (step.params,))
        ok = False

    # plate_solve survives alongside a Params offset
    step = ssp_sequence.step_from_fields('GOTO', 'V', '',
                                         'OFFSET,0.5,0.25, plate_solve=0')
    if step.params.get('plate_solve') != 0:
        print("  ✗ plate_solve lost with Params offset: %r" % (step.params,))
        ok = False
    # a plain star is unaffected
    step = ssp_sequence.step_from_fields('GOTO', 'C', '', 'plate_solve=1')
    if step.params.get('star_ref') != 'C' or step.params.get('plate_solve') != 1:
        print("  ✗ plain star broken: %r" % (step.params,))
        ok = False

    # editor field round-trip keeps the star and the offset
    step = ssp_sequence.step_from_fields('GOTO', 'V', '', 'OFFSET,0.0,0.25')
    rebuilt = ssp_sequence.step_from_fields(*ssp_sequence.fields_from_step(step))
    if rebuilt.params != step.params:
        print("  ✗ editor round-trip: %r -> %r" % (step.params, rebuilt.params))
        ok = False
    return ok


# --- Test 13: sequence editor field round-trip -------------------------------

def test_sequence_editor_fields():
    print("\nTesting sequence editor field round-trip...")
    try:
        import ssp_sequence
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True
    cases = [
        ('GOTO', 'C', '', ''),
        ('GOTO', '12.5,-30.25', '', ''),
        ('GOTO', 'OFFSET,0.0,0.25', '', ''),
        ('TARGET', 'OMI CET', '', ''),
        ('TARGET', 'auid=000-BBW-425', '', ''),
        ('TARGET', 'OMI CET', '', 'id=auid'),
        ('MEASURE', '', '', 'filter=V, integ=5, interval=3'),
        ('SKY', '', 'SKYLAST', 'offset=0.0,0.25'),
        ('FILTER', 'B', '', ''),
        ('WAIT', '2.5', '', ''),
        ('WAIT_UNTIL', '2026-11-27 02:45:00', '', ''),
        ('ABORT_IF', '', '', 'airmass_above=2.5'),
        ('REPEAT', '3', '', ''),
        ('END', '', '', ''),
    ]
    ok = True
    for kind, value, label, params in cases:
        st = ssp_sequence.step_from_fields(kind, value, label, params)
        k2, v2, l2, p2 = ssp_sequence.fields_from_step(st)
        st2 = ssp_sequence.step_from_fields(k2, v2, l2, p2)
        if not (st.kind == st2.kind and st.params == st2.params):
            print("  ✗ round-trip %s %r -> %r" % (kind, st.params, st2.params))
            ok = False
    if ok:
        print("  ✓ all %d step kinds round-trip through the editor fields" % len(cases))
    return ok


# --- Test 14: named sequence storage (save / load / list / delete) -----------

def test_sequence_named_storage():
    print("\nTesting sequence named storage (save/load/list/delete)...")
    try:
        import ssp_sequence
        import System
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True
    tmp = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ssp_seq_test")
    ok = True
    try:
        sd = ssp_sequence.sequences_dir(tmp)
        seq = ssp_sequence.build_templates()['V-C-V-C']
        seq.max_observations = 8
        ssp_sequence.save_named(seq, sd)
        if 'V-C-V-C' in ssp_sequence.list_names(sd):
            print("  ✓ saved and listed 'V-C-V-C'")
        else:
            print("  ✗ not listed: %s" % (ssp_sequence.list_names(sd),))
            ok = False
        seq2 = ssp_sequence.load_named(sd, 'V-C-V-C')
        if ([s.kind for s in seq2.steps] == [s.kind for s in seq.steps]
                and seq2.max_observations == 8):
            print("  ✓ loaded back identical kinds + run length")
        else:
            print("  ✗ load mismatch")
            ok = False
        ssp_sequence.delete_named(sd, 'V-C-V-C')
        if 'V-C-V-C' not in ssp_sequence.list_names(sd):
            print("  ✓ deleted")
        else:
            print("  ✗ still present after delete")
            ok = False
    except Exception as e:
        print("  ✗ storage error: " + str(e))
        ok = False
    finally:
        try:
            System.IO.Directory.Delete(tmp, True)
        except Exception:
            pass
    return ok


# --- Test 15: compulsory autosave --------------------------------------------

_AUTOSAVE_METHODS = ('take_reading', '_collect_counts', '_format_data_line',
                     '_format_data_line_tab', '_filter_position_for_name',
                     '_autosave_header_info', '_autosave_target', '_autosave_dir',
                     '_autosave_safe', '_autosave_start',
                     '_write_autosave_raw_header', '_write_autosave_tab_header',
                     '_autosave_reading')


def _make_autosave_window(tmp_dir):
    """A _SeqWindow with take_reading + the real autosave methods bound."""
    import ssp_dataaq
    W = ssp_dataaq.SSPDataAcquisitionWindow
    cfg = _FakeConfig({'auto_manual': 'M', 'telescope_name': 'Tel X',
                       'observer_name': 'Obs Y', 'last_conditions': 'Clear',
                       'last_data_directory': tmp_dir})
    cfg.config_dir = tmp_dir
    w = _SeqWindow(_FakeComm(counts=["00496"]), cfg)
    w.current_target = _ExecTriple(_ExecStar('V PER', 12.0, 30.0))
    w._autosave_key = None
    w._autosave_raw = None
    w._autosave_tab = None
    w._autosave_header_written = False
    for name in _AUTOSAVE_METHODS:
        func = getattr(W, name)
        setattr(w, name, lambda *a, _f=func, **k: _f(w, *a, **k))
    return w


def test_autosave():
    print("\nTesting compulsory autosave (.raw + .tab append)...")
    if _has_take_reading() is None:
        return True
    try:
        import System
        import re
    except Exception as e:
        print("  ⚠ skipped: " + str(e))
        return True

    tmp = System.IO.Path.Combine(System.IO.Path.GetTempPath(), "ssp_autosave_test")
    ok = True
    try:
        w = _make_autosave_window(tmp)
        _with_fake_datetime(lambda: w.take_reading(
            "V PER", "V", "V", "10", 5.0, 1, "slow", headless=True))
        _with_fake_datetime(lambda: w.take_reading(
            "COMP", "C", "V", "10", 5.0, 1, "slow", headless=True))

        raw = w._autosave_raw
        tab = w._autosave_tab
        if raw and System.IO.File.Exists(raw) and System.IO.File.Exists(tab):
            print("  ✓ created .raw and .tab")
        else:
            print("  ✗ files missing: %r %r" % (raw, tab))
            ok = False

        name = System.IO.Path.GetFileName(raw or "")
        if re.match(r'^\d{6}-\d{6}-V_PER\.raw$', name):
            print("  ✓ filename %s" % name)
        else:
            print("  ✗ filename %s" % name)
            ok = False

        raw_lines = System.IO.File.ReadAllLines(raw)
        tab_lines = System.IO.File.ReadAllLines(tab)
        if len(raw_lines) == 6 and len(tab_lines) == 6:
            print("  ✓ header written once + 2 appended readings")
        else:
            print("  ✗ raw=%d tab=%d lines" % (len(raw_lines), len(tab_lines)))
            ok = False
        if raw_lines[0].startswith(" FILENAME=") and raw_lines[3].startswith(" MO-DY-YEAR"):
            print("  ✓ .raw header lines correct")
        else:
            print("  ✗ .raw header: %r" % (raw_lines[0],))
            ok = False
    except Exception as e:
        print("  ✗ autosave error: " + str(e))
        ok = False
    finally:
        try:
            System.IO.Directory.Delete(tmp, True)
        except Exception:
            pass
    return ok


# --- Runner ------------------------------------------------------------------






def main():
    """Run all tests."""
    print("=" * 60)
    print("Sequence Engine Test Suite (Phases 1-2)")
    print("=" * 60)

    tests = [
        ("take_reading parity with _on_start", test_take_reading_parity),
        ("take_reading gain coercion", test_take_reading_gain_coercion),
        ("take_reading / _collect_counts guards", test_take_reading_guards),
        ("6/8 binning + retry/target fallback", test_collect_counts_binning),
        ("_filter_position_for_name mapping", test_filter_position_for_name),
        ("executor step order", test_executor_order),
        ("executor stop conditions", test_executor_stop_conditions),
        ("executor REPEAT nesting", test_executor_repeat),
        ("executor pause hold", test_executor_pause),
        ("executor star resolution", test_executor_resolve_star),
        ("executor offset/RA-Dec math", test_executor_offset_math),
        ("executor sky reading", test_executor_sky),
        ("executor GOTO standalone/headless", test_executor_goto_standalone),
        ("executor per-step plate_solve override", test_executor_plate_solve_override),
        ("RA/Dec offset formatting", test_coord_formatting),
        ("GOTO OFFSET from the Params box", test_goto_offset_from_params),
        ("TARGET catalog validation helpers", test_target_catalog_validation),
        ("executor TARGET step", test_executor_target),
        (".ssp text round-trip", test_ssp_text_roundtrip),
        ("executor WAIT_UNTIL", test_executor_wait_until),
        ("sequence editor field round-trip", test_sequence_editor_fields),
        ("sequence named storage", test_sequence_named_storage),
        ("compulsory autosave", test_autosave),
    ]

    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            import traceback
            print("\n✗ Test '%s' crashed: %s" % (test_name, str(e)))
            print(traceback.format_exc())
            results.append((test_name, False))

    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    passed = 0
    failed = 0
    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        symbol = "✓" if result else "✗"
        print("%s %s: %s" % (symbol, test_name, status))
        if result:
            passed += 1
        else:
            failed += 1

    print("\nTotal: %d passed, %d failed" % (passed, failed))

    if failed == 0:
        print("\n✓ All tests passed!")
    else:
        print("\n✗ Some tests failed")

    return failed == 0


if __name__ == '__main__':
    success = main()
    # Return an exit code only when run as a real script (ipy test_sequence.py),
    # so run_ipy_test.ps1 / CI can read $LASTEXITCODE. In the SharpCap console or
    # an exec() context sys.argv[0] is SharpCap itself, and the SystemExit raised
    # by sys.exit() is printed as a traceback even on success - so skip it there.
    if sys.argv and str(sys.argv[0]).endswith('test_sequence.py'):
        sys.exit(0 if success else 1)





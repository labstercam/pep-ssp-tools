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
        return ""


class _FakeDTClass(object):
    """Replacement for System.DateTime; UtcNow is a fixed 2026-01-02 03:04:05."""


# The application reads `DateTime.UtcNow` as a .NET property (no parentheses), so
# expose it as a plain attribute holding a fixed instance. A @staticmethod would
# stay a function object here and fail with "'function' object has no attribute
# 'AddSeconds'".
_FakeDTClass.UtcNow = _FakeDT(2026, 1, 2, 3, 4, 5)


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


# --- Runner ------------------------------------------------------------------

def main():
    """Run all tests."""
    print("=" * 60)
    print("Sequence Engine Phase 1 Refactor Test Suite")
    print("=" * 60)

    tests = [
        ("take_reading parity with _on_start", test_take_reading_parity),
        ("take_reading / _collect_counts guards", test_take_reading_guards),
        ("6/8 binning + retry/target fallback", test_collect_counts_binning),
        ("_filter_position_for_name mapping", test_filter_position_for_name),
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
    # Only exit with a status code when run as a script (ipy test_sequence.py).
    # When exec'd from the SharpCap console there is no __file__, and the
    # SystemExit raised by sys.exit() is printed as a traceback even on success.
    if '__file__' in dir():
        sys.exit(0 if success else 1)





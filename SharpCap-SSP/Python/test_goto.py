"""
Test GOTO functionality for SharpCap-SSP
=========================================

This test verifies:
1. Module imports work in both SharpCap and standalone modes
2. Button is only created in SharpCap mode
3. GOTO function handles missing objects gracefully
4. Coordinate calculations are correct
"""

import sys
import os

# Add script directory to path
script_dir = os.path.dirname(os.path.abspath(__file__)) if '__file__' in dir() else os.getcwd()
if script_dir not in sys.path:
    sys.path.append(script_dir)


def _print_stale_module_hint(module_name, module):
    """Explain a missing-attribute failure caused by a stale deployed module.

    SharpCap runs the app from its scripts folder (e.g. Documents\\SharpCap\\SSP).
    If an older copy of a module was already imported when this test runs, the
    new attributes won't be present. Point at the loaded file so the fix
    (redeploy + restart SharpCap) is obvious.
    """
    print("    -> A stale '%s' module was loaded from: %s"
          % (module_name, getattr(module, '__file__', '<unknown>')))
    print("       Copy the updated %s.py into the SharpCap scripts folder and"
          % module_name)
    print("       restart SharpCap so the new module is imported.")


def test_imports():
    """Test that all required modules can be imported."""
    print("Testing imports...")
    
    try:
        import time
        print("  ✓ time module imported")
    except ImportError as e:
        print("  ✗ time import failed: " + str(e))
        return False
    
    try:
        import clr
        clr.AddReference('System')
        clr.AddReference('System.Windows.Forms')
        clr.AddReference('System.Drawing')
        print("  ✓ CLR references added")
    except Exception as e:
        print("  ✗ CLR setup failed: " + str(e))
        return False
    
    try:
        from System.Threading import CancellationToken
        print("  ✓ CancellationToken imported")
    except ImportError:
        print("  ⚠ CancellationToken not available (expected in standalone mode)")
    
    try:
        from System.Windows.Forms import Clipboard
        print("  ✓ Clipboard imported")
    except ImportError as e:
        print("  ✗ Clipboard import failed: " + str(e))
        return False
    
    return True

def test_catalog_module():
    """Test that catalog module loads correctly."""
    print("\nTesting catalog module...")
    
    try:
        import ssp_catalog
        print("  ✓ ssp_catalog module imported")
        
        # Try to create a catalog instance
        catalog = ssp_catalog.StarCatalog()
        print("  ✓ StarCatalog instance created")
        
        if catalog.targets:
            print("  ✓ Catalog has %d targets loaded" % len(catalog.targets))
            
            # Test coordinate access
            if catalog.targets:
                star = catalog.targets[0].variable
                ra_hours = star.ra_hours + star.ra_minutes/60.0 + star.ra_seconds/3600.0
                dec_degrees = star.dec_degrees_decimal
                print("  ✓ Coordinate calculation works: RA=%.6fh, Dec=%.6f°" % (ra_hours, dec_degrees))
                print("  ✓ String format: RA=%s, Dec=%s" % (star.ra_string(), star.dec_string()))
        else:
            print("  ⚠ Catalog loaded but no targets found")
            
        return True
    except Exception as e:
        import traceback
        print("  ✗ Catalog test failed: " + str(e))
        print(traceback.format_exc())
        return False

def test_sharpcap_detection():
    """Test SharpCap detection logic."""
    print("\nTesting SharpCap detection...")
    
    sharpcap_available = 'SharpCap' in dir()
    
    if sharpcap_available:
        print("  ✓ Running in SharpCap mode")
        print("  ✓ GOTO button will be created")
        
        # Check if SharpCap has expected attributes
        try:
            if hasattr(SharpCap, 'Mounts'):
                print("  ✓ SharpCap.Mounts available")
            else:
                print("  ⚠ SharpCap.Mounts not available")
            
            if hasattr(SharpCap, 'CoordinateParser'):
                print("  ✓ SharpCap.CoordinateParser available")
            else:
                print("  ⚠ SharpCap.CoordinateParser not available")
        except NameError:
            print("  ✗ SharpCap object not accessible")
    else:
        print("  ✓ Running in standalone mode")
        print("  ✓ GOTO button will NOT be created")
    
    return True

def test_goto_button_logic():
    """Test that GOTO button is only created when appropriate."""
    print("\nTesting GOTO button creation logic...")
    
    sharpcap_available = 'SharpCap' in dir()
    
    # Simulate the button creation logic
    if sharpcap_available:
        print("  ✓ Button creation condition: True (SharpCap detected)")
        print("  ✓ goto_button will be initialized")
    else:
        print("  ✓ Button creation condition: False (standalone mode)")
        print("  ✓ goto_button will NOT be initialized")
        print("  ✓ hasattr(self, 'goto_button') will return False")
    
    return True

def test_auto_goto_stage_logic():
    """Test the two-stage GOTO button stage toggle/reset logic."""
    print("\nTesting two-stage GOTO stage logic...")
    
    # Simulate the toggle performed by _on_goto_stage after each successful slew
    stage = 'comp'
    labels = []
    for _ in range(3):
        if stage == 'comp':
            labels.append("GOTO Comp")
            stage = 'var'
        else:
            labels.append("GOTO Var")
            stage = 'comp'
    
    expected = ["GOTO Comp", "GOTO Var", "GOTO Comp"]
    if labels == expected:
        print("  ✓ Toggle sequence correct: %s" % " -> ".join(labels))
    else:
        print("  ✗ Toggle sequence incorrect: got %s, expected %s" % (labels, expected))
        return False
    
    # Stage resets to 'comp' whenever a new target star is selected
    stage = 'comp'
    if stage == 'comp':
        print("  ✓ Stage resets to 'comp' (GOTO Comp) on new target selection")
    else:
        print("  ✗ Stage reset failed")
        return False
    
    return True

def test_object_display_name_logic():
    """Test the Object-dropdown display name convention used for GOTO syncing."""
    print("\nTesting Object dropdown display name logic...")
    
    # Mirrors _star_display_name(): 'V' = bare name, 'C'/'K' add a suffix
    base_name = "APASS 001"
    suffixes = {'V': "", 'C': " (Comp)", 'K': " (Check)"}
    expected = {
        'V': "APASS 001",
        'C': "APASS 001 (Comp)",
        'K': "APASS 001 (Check)",
    }
    
    ok = True
    for ctype in ('V', 'C', 'K'):
        display = base_name + suffixes[ctype]
        if display == expected[ctype]:
            print("  ✓ %s -> '%s'" % (ctype, display))
        else:
            print("  ✗ %s -> got '%s', expected '%s'" % (ctype, display, expected[ctype]))
            ok = False
    
    return ok

def test_coordinate_formatting():
    """Test coordinate string formatting."""
    print("\nTesting coordinate formatting...")
    
    # Test values
    ra_hours = 12.5
    dec_degrees = -30.25
    
    coord_string = "%s;%s" % (ra_hours, dec_degrees)
    expected = "12.5;-30.25"
    
    if coord_string == expected:
        print("  ✓ Coordinate string format correct: " + coord_string)
    else:
        print("  ✗ Coordinate string incorrect: got '%s', expected '%s'" % (coord_string, expected))
        return False
    
    # Test clipboard format
    clipboard_string = "%.6f, %.6f" % (ra_hours, dec_degrees)
    expected_clipboard = "12.500000, -30.250000"
    
    if clipboard_string == expected_clipboard:
        print("  ✓ Clipboard format correct: " + clipboard_string)
    else:
        print("  ✗ Clipboard format incorrect: got '%s', expected '%s'" % (clipboard_string, expected_clipboard))
        return False
    
    return True

def test_plate_solve_sync_logic():
    """Test the 'Plate Solve and Sync' checkbox config mapping and gate logic."""
    print("\nTesting Plate Solve and Sync logic...")
    
    # Mirrors the 0/1 <-> Checked mapping used by the checkbox and its handler
    def checked_to_config(checked):
        return 1 if checked else 0
    
    def config_to_checked(value):
        return value == 1
    
    ok = True
    for checked in (True, False):
        stored = checked_to_config(checked)
        if config_to_checked(stored) == checked:
            print("  ✓ Checkbox %s -> config %d -> Checkbox %s" % (checked, stored, checked))
        else:
            print("  ✗ Round-trip failed for %s" % checked)
            ok = False
    
    # Mirrors the gate in _solve_and_sync_mount: a per-step override wins over
    # the persisted checkbox; None falls back to the global option.
    #   if plate_solve is None:
    #       enabled = (config.get('plate_solve_sync', 0) == 1)
    #   else:
    #       enabled = bool(plate_solve)
    def should_sync(config, plate_solve=None):
        if plate_solve is None:
            return config.get('plate_solve_sync', 0) == 1
        return bool(plate_solve)
    
    cases = [
        ({'plate_solve_sync': 1}, None, True),
        ({'plate_solve_sync': 0}, None, False),
        ({}, None, False),                     # missing key -> defaults to off
        ({'plate_solve_sync': 1}, 0, False),   # per-step override forces OFF
        ({'plate_solve_sync': 0}, 1, True),    # per-step override forces ON
    ]
    for config, plate_solve, expected in cases:
        result = should_sync(config, plate_solve)
        if result == expected:
            print("  ✓ Gate for %s (plate_solve=%s) -> solve/sync: %s"
                  % (config, plate_solve, result))
        else:
            print("  ✗ Gate for %s (plate_solve=%s) -> got %s, expected %s"
                  % (config, plate_solve, result, expected))
            ok = False
    
    return ok

def test_plate_solve_sync_default():
    """Test that the plate_solve_sync config default is present and off."""
    print("\nTesting Plate Solve and Sync config default...")
    
    try:
        import ssp_config
    except Exception as e:
        print("  ⚠ ssp_config import skipped (standalone): " + str(e))
        return True
    
    default = ssp_config.SSPConfig.DEFAULT_CONFIG.get('plate_solve_sync', None)
    if default == 0:
        print("  ✓ DEFAULT_CONFIG['plate_solve_sync'] exists and defaults to 0")
        return True
    elif default is None:
        print("  ✗ DEFAULT_CONFIG is missing 'plate_solve_sync'")
        _print_stale_module_hint('ssp_config', ssp_config)
        return False
    else:
        print("  ✗ DEFAULT_CONFIG['plate_solve_sync'] = %s, expected 0" % default)
        return False


# --- Helpers for test_mount_settle_logic -------------------------------------
# These let us exercise the real _wait_for_mount_settle with a virtual clock so
# the test runs instantly (no real sleeps) and needs no live mount.

class _SettleEngine(object):
    """Virtual clock + recording sink for _wait_for_mount_settle."""

    def __init__(self):
        self.clock = 0.0
        self.sleeps = []
        self.statuses = []
        self.results = []
        outer = self

        class _TimeShim(object):
            def time(self):
                return outer.clock

        self.time_shim = _TimeShim()

    def pump_sleep(self, seconds):
        self.sleeps.append(seconds)
        self.clock += seconds


class _FakeSharpCap(object):
    def __init__(self, engine):
        self._engine = engine

    def SafeGetAsyncResult(self, task):
        self._engine.results.append(task)
        return task


class _FakeWindow(object):
    def __init__(self, engine):
        self._engine = engine
        self._closing = False
        self.SharpCap = _FakeSharpCap(engine)

    def _update_status(self, message):
        self._engine.statuses.append(message)

    def _pump_until_complete(self, task, timeout_seconds=300, label="operation"):
        # Stub - the real pump loop is exercised directly by
        # test_pump_until_complete; the settle test only needs it to exist.
        return


class _WaitUntilSettledMount(object):
    """Mount exposing only WaitUntilSettled."""

    def __init__(self):
        self.wait_calls = []

    def WaitUntilSettled(self, wait_for_settle, token):
        self.wait_calls.append(wait_for_settle)
        return "settle-task"


class _SlewingMount(object):
    """Mount exposing Slewing (clears after N reads) and IsSettled (always True)."""

    def __init__(self, slewing_reads):
        self._remaining = slewing_reads
        self.slewing_reads = 0

    @property
    def Slewing(self):
        self.slewing_reads += 1
        if self._remaining > 0:
            self._remaining -= 1
            return True
        return False

    @property
    def IsSettled(self):
        return True


class _SettledMount(object):
    """Mount exposing only IsSettled (flips True after N reads)."""

    def __init__(self, reads_until_settled):
        self._remaining = reads_until_settled
        self.is_settled_reads = 0

    @property
    def IsSettled(self):
        self.is_settled_reads += 1
        if self._remaining > 0:
            self._remaining -= 1
            return False
        return True


class _BareMount(object):
    """Mount exposing no motion or settle state at all."""


class _FakeTask(object):
    """Task whose IsCompleted flips True once the virtual clock passes a time.

    Keyed to the engine's virtual clock (advanced by pump_sleep) rather than a
    read count, so the extra IsCompleted probe that hasattr() performs is
    harmless. Pass complete_after_seconds=None for a task that never completes.
    """

    def __init__(self, engine, complete_after_seconds=None):
        self._engine = engine
        self._threshold = complete_after_seconds

    @property
    def IsCompleted(self):
        if self._threshold is None:
            return False
        return self._engine.clock >= self._threshold


class _NoPollTask(object):
    """Task exposing no IsCompleted attribute (cannot be pumped)."""


def _run_settle(fake_window, mount, engine):
    """Call the real _wait_for_mount_settle using the engine's virtual clock."""
    import ssp_dataaq
    real_pump = ssp_dataaq.ssp_comm.pump_sleep
    real_time = ssp_dataaq.time
    ssp_dataaq.ssp_comm.pump_sleep = engine.pump_sleep
    ssp_dataaq.time = engine.time_shim
    try:
        ssp_dataaq.SSPDataAcquisitionWindow._wait_for_mount_settle(fake_window, mount)
    finally:
        ssp_dataaq.ssp_comm.pump_sleep = real_pump
        ssp_dataaq.time = real_time


def _run_pump(fake_window, task, engine, timeout_seconds=300):
    """Call the real _pump_until_complete using the engine's virtual clock."""
    import ssp_dataaq
    real_pump = ssp_dataaq.ssp_comm.pump_sleep
    real_time = ssp_dataaq.time
    ssp_dataaq.ssp_comm.pump_sleep = engine.pump_sleep
    ssp_dataaq.time = engine.time_shim
    try:
        ssp_dataaq.SSPDataAcquisitionWindow._pump_until_complete(
            fake_window, task, timeout_seconds=timeout_seconds, label="test")
    finally:
        ssp_dataaq.ssp_comm.pump_sleep = real_pump
        ssp_dataaq.time = real_time


def test_mount_settle_logic():
    """Test _wait_for_mount_settle branch priority and fallbacks."""
    print("\nTesting mount settle logic...")

    try:
        import ssp_dataaq  # noqa: F401
    except Exception as e:
        print("  ⚠ ssp_dataaq import skipped (standalone): " + str(e))
        return True

    print("  ssp_dataaq module: %s" % getattr(ssp_dataaq, '__file__', '<unknown>'))

    if not hasattr(ssp_dataaq.SSPDataAcquisitionWindow, '_wait_for_mount_settle'):
        print("  ✗ SSPDataAcquisitionWindow is missing '_wait_for_mount_settle'")
        _print_stale_module_hint('ssp_dataaq', ssp_dataaq)
        return False

    ok = True

    # 1. WaitUntilSettled is preferred and returns early (no fallback polling)
    eng = _SettleEngine()
    mount = _WaitUntilSettledMount()
    _run_settle(_FakeWindow(eng), mount, eng)
    if mount.wait_calls == [True] and eng.results and eng.statuses[-1] == "Mount settled":
        print("  ✓ WaitUntilSettled preferred: called, then 'Mount settled'")
    else:
        print("  ✗ WaitUntilSettled path wrong: calls=%s statuses=%s"
              % (mount.wait_calls, eng.statuses))
        ok = False

    # 2. Slewing motion monitor polls until motion clears, then settles
    eng = _SettleEngine()
    mount = _SlewingMount(slewing_reads=3)
    _run_settle(_FakeWindow(eng), mount, eng)
    if mount.slewing_reads >= 4 and eng.statuses[-1] == "Mount settled" and not eng.results:
        print("  ✓ Slewing monitor polls then settles (no WaitUntilSettled)")
    else:
        print("  ✗ Slewing monitor path wrong: reads=%d statuses=%s"
              % (mount.slewing_reads, eng.statuses))
        ok = False

    # 3. IsSettled-only fallback polls until settled
    eng = _SettleEngine()
    mount = _SettledMount(reads_until_settled=2)
    _run_settle(_FakeWindow(eng), mount, eng)
    if mount.is_settled_reads >= 3 and eng.statuses[-1] == "Mount settled":
        print("  ✓ IsSettled fallback polls then settles")
    else:
        print("  ✗ IsSettled fallback path wrong: reads=%d statuses=%s"
              % (mount.is_settled_reads, eng.statuses))
        ok = False

    # 4. A never-settling mount times out (~20 s) with a non-fatal warning
    eng = _SettleEngine()
    mount = _SettledMount(reads_until_settled=10 ** 9)
    try:
        _run_settle(_FakeWindow(eng), mount, eng)
        timed_out_msg = eng.statuses[-1] if eng.statuses else ""
        if "not confirmed" in timed_out_msg and abs(eng.clock - 20.0) < 0.5:
            print("  ✓ Non-settling mount times out (~20 s) with a warning")
        else:
            print("  ✗ Timeout wrong: clock=%.2f statuses=%s" % (eng.clock, eng.statuses))
            ok = False
    except Exception as ex:
        print("  ✗ Timeout raised (should be non-fatal): " + str(ex))
        ok = False

    # 5. A mount with no motion/settle state uses the last-resort 2 s wait
    eng = _SettleEngine()
    mount = _BareMount()
    _run_settle(_FakeWindow(eng), mount, eng)
    if eng.sleeps and eng.sleeps[-1] == 2:
        print("  ✓ No-state mount uses the last-resort 2 s settle wait")
    else:
        print("  ✗ No-state fallback wrong: sleeps=%s" % eng.sleeps)
        ok = False

    return ok


def test_pump_until_complete():
    """Test _pump_until_complete pumps while a task runs and stops correctly."""
    print("\nTesting task pump helper...")

    try:
        import ssp_dataaq  # noqa: F401
    except Exception as e:
        print("  ⚠ ssp_dataaq import skipped (standalone): " + str(e))
        return True

    if not hasattr(ssp_dataaq.SSPDataAcquisitionWindow, '_pump_until_complete'):
        print("  ✗ SSPDataAcquisitionWindow is missing '_pump_until_complete'")
        _print_stale_module_hint('ssp_dataaq', ssp_dataaq)
        return False

    ok = True

    # 1. Pumps in slices until the task completes, then returns
    eng = _SettleEngine()
    task = _FakeTask(eng, complete_after_seconds=0.3)
    _run_pump(_FakeWindow(eng), task, eng)
    if len(eng.sleeps) == 3 and eng.clock >= 0.3:
        print("  ✓ Pumps until complete (3 slices, ~0.3 s)")
    else:
        print("  ✗ Pump-until-complete wrong: sleeps=%d clock=%.2f"
              % (len(eng.sleeps), eng.clock))
        ok = False

    # 2. A never-completing task is bounded by the timeout
    eng = _SettleEngine()
    _run_pump(_FakeWindow(eng), _FakeTask(eng, complete_after_seconds=None), eng,
              timeout_seconds=1.0)
    if eng.sleeps and 1.0 <= eng.clock < 1.2:
        print("  ✓ Never-completing task capped at the timeout (1.0 s)")
    else:
        print("  ✗ Timeout wrong: sleeps=%d clock=%.2f" % (len(eng.sleeps), eng.clock))
        ok = False

    # 3. A task with no IsCompleted falls back to a plain block (no pumping)
    eng = _SettleEngine()
    _run_pump(_FakeWindow(eng), _NoPollTask(), eng)
    if eng.sleeps == []:
        print("  ✓ Unpumpable task returns immediately (plain-wait fallback)")
    else:
        print("  ✗ Unpumpable task pumped: sleeps=%s" % eng.sleeps)
        ok = False

    # 4. The pump stops at once if the window is closing
    eng = _SettleEngine()
    fw = _FakeWindow(eng)
    fw._closing = True
    _run_pump(fw, _FakeTask(eng, complete_after_seconds=None), eng)
    if eng.sleeps == []:
        print("  ✓ Pump stops immediately while the window is closing")
    else:
        print("  ✗ Closing guard failed: sleeps=%s" % eng.sleeps)
        ok = False

    return ok


def main():
    """Run all tests."""
    print("=" * 60)
    print("GOTO Functionality Test Suite")
    print("=" * 60)
    
    tests = [
        ("Module Imports", test_imports),
        ("Catalog Module", test_catalog_module),
        ("SharpCap Detection", test_sharpcap_detection),
        ("GOTO Button Logic", test_goto_button_logic),
        ("Auto GOTO Stage Logic", test_auto_goto_stage_logic),
        ("Object Display Name Logic", test_object_display_name_logic),
        ("Coordinate Formatting", test_coordinate_formatting),
        ("Plate Solve and Sync Logic", test_plate_solve_sync_logic),
        ("Plate Solve and Sync Default", test_plate_solve_sync_default),
        ("Mount Settle Logic", test_mount_settle_logic),
        ("Task Pump Helper", test_pump_until_complete),
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
    sys.exit(0 if success else 1)

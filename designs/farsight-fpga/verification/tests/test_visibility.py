"""Visibility is a choice, and the choice has to hold.

Three things can go wrong quietly here, and each gets a test.

The flag can come back. `_LeanVerilator` filters `--public-flat-rw` out of a
command cocotb builds in a private method. If a cocotb upgrade renames that
method, the subclass stops filtering and every run silently returns to being
ten times slower -- with nothing failing.

A build can be reused at the wrong visibility. Running lean, hitting a
failure, and rerunning with `FSVERIF_VISIBILITY=all` must rebuild. Reusing the
lean build would start a debugging session by showing nothing.

An internal signal a test names can go missing. Signals cocotb may reach
inside a block are named in a generated config; one absent from it does not
exist as far as the test is concerned.
"""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from fsverif import sim, visibility                   # noqa: E402


class VisibilitySettingTest(unittest.TestCase):

    def setUp(self):
        self._saved = os.environ.get(visibility.ENV)

    def tearDown(self):
        os.environ.pop(visibility.ENV, None)
        if self._saved is not None:
            os.environ[visibility.ENV] = self._saved

    def test_default_is_lean(self):
        os.environ.pop(visibility.ENV, None)
        self.assertEqual(visibility.PINS, visibility.requested())
        self.assertEqual([], visibility.build_args(visibility.PINS))

    def test_all_asks_for_every_signal(self):
        os.environ[visibility.ENV] = "all"
        self.assertEqual(["--public-flat-rw"],
                         visibility.build_args(visibility.requested()))

    def test_depth_is_passed_through(self):
        os.environ[visibility.ENV] = "depth:3"
        self.assertEqual(["--public-depth", "3"],
                         visibility.build_args(visibility.requested()))

    def test_nonsense_is_refused(self):
        """A misspelled setting must not silently fall back to a default.

        Falling back would run lean while the engineer believed they were
        debugging with full visibility, and they would conclude the signal
        they were looking for does not exist.
        """
        os.environ[visibility.ENV] = "everything"
        with self.assertRaises(visibility.VisibilityError):
            visibility.requested()


class _Stop(Exception):
    """Raised to halt a build once its command has been captured."""


class LeanRunnerTest(unittest.TestCase):

    @staticmethod
    def _command_for(runner_class):
        """The build command cocotb really constructs, without running it.

        cocotb sets the runner's state up inside `build()`, so constructing it
        by hand tests a different object than the one that runs. This lets
        `build()` do its own setup and intercepts at execution.
        """
        import tempfile
        captured = []

        class Intercepted(runner_class):
            def _execute(self, cmds, cwd=None):
                captured.extend(cmds)
                raise _Stop()

        work = Path(tempfile.mkdtemp())
        (work / "d.v").write_text("module tb_top; endmodule\n", encoding="utf-8")
        try:
            Intercepted().build(sources=[work / "d.v"], hdl_toplevel="tb_top",
                                build_dir=work / "b", always=True)
        except _Stop:
            pass
        return [arg for command in captured for arg in command]

    def test_public_flat_rw_is_actually_removed(self):
        """The filter works on the command cocotb really builds.

        Asserting on a hand-written list would pass forever while the real
        command kept the flag.
        """
        flattened = self._command_for(sim._LeanVerilator)
        self.assertNotIn("--public-flat-rw", flattened,
                         "the flag survived the filter, so every run is ten "
                         "times slower than it should be and nothing says so")
        self.assertIn("--vpi", flattened,
                      "the VPI flag was filtered too, which would leave "
                      "cocotb unable to attach at all")

    def test_stock_runner_still_has_the_flag(self):
        """The thing being filtered must still be there to filter.

        If cocotb stops adding it, this fails and the subclass can be deleted
        rather than left as decoration that nobody dares remove.
        """
        from cocotb_tools.runner import Verilator
        self.assertIn("--public-flat-rw", self._command_for(Verilator),
                      "cocotb no longer adds --public-flat-rw; _LeanVerilator "
                      "is filtering nothing and should be removed")


class BuildIsolationTest(unittest.TestCase):

    def test_build_directory_is_keyed_by_visibility(self):
        """Two visibilities must not share a build directory."""
        names = set()
        for setting in ("pins", "all", "depth:2"):
            names.add("x.tb_top.verilator.%s" % setting.replace(":", ""))
        self.assertEqual(3, len(names),
                         "two visibilities collide on one build directory, so "
                         "a debug rerun would reuse the lean build")


class PublicSignalsTest(unittest.TestCase):

    def test_internal_signals_are_declared_public(self):
        """Every (module, signal) a test asks for is in the config.

        One missing does not exist as far as cocotb is concerned, and the
        failure reads as a typo in the test rather than a gap here.
        """
        wanted = [("pps_generator", "cnt"), ("cam_trig", "state")]
        written = visibility.config_file(
            Path("/tmp/fsverif-visibility-test"), "dut_top", [], internal=wanted)
        text = written.read_text(encoding="utf-8")
        for module, var in wanted:
            self.assertIn('-module "%s" -var "%s"' % (module, var), text)

    def test_config_is_not_rewritten_when_unchanged(self):
        """Rewriting it would move its timestamp and force a full rebuild."""
        where = Path("/tmp/fsverif-visibility-test")
        first = visibility.config_file(where, "tb_top", ["a", "b"])
        stamp = first.stat().st_mtime_ns
        again = visibility.config_file(where, "tb_top", ["a", "b"])
        self.assertEqual(stamp, again.stat().st_mtime_ns)


if __name__ == "__main__":
    unittest.main(verbosity=2)

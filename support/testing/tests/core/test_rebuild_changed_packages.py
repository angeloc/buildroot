import glob
import os
import shutil
import subprocess
import time

import infra
import infra.basetest

TEST_PATCH = """Add a file, to check that adding a patch rebuilds the package.

Signed-off-by: Buildroot test <buildroot@buildroot.org>
---
--- /dev/null
+++ b/buildroot-rebuild-test.txt
@@ -0,0 +1 @@
+test
"""

# A br2-external tree with a package built against pciutils, which
# installs the value set in its .mk file. It installs it in a directory
# of the skeleton that has no other file, without creating it, as some
# packages do: removing the package must not remove the directory.
EXTERNAL = {
    "external.desc": "name: REBUILD_TEST\n",
    "Config.in": 'source "$BR2_EXTERNAL_REBUILD_TEST_PATH/package/rebuild-test/Config.in"\n',
    "external.mk": "include $(sort $(wildcard $(BR2_EXTERNAL_REBUILD_TEST_PATH)/package/*/*.mk))\n",
    "package/rebuild-test/Config.in":
        'config BR2_PACKAGE_REBUILD_TEST\n'
        '\tbool "rebuild-test"\n'
        '\tselect BR2_PACKAGE_PCIUTILS\n',
    "package/rebuild-test/src/README": "Package of the rebuild test.\n",
    "package/rebuild-test/rebuild-test.mk":
        'REBUILD_TEST_VERSION = 1.0\n'
        'REBUILD_TEST_SITE = $(BR2_EXTERNAL_REBUILD_TEST_PATH)/package/rebuild-test/src\n'
        'REBUILD_TEST_SITE_METHOD = local\n'
        'REBUILD_TEST_DEPENDENCIES = pciutils\n'
        'REBUILD_TEST_VALUE = 1\n'
        '\n'
        'define REBUILD_TEST_BUILD_CMDS\n'
        '\techo $(REBUILD_TEST_VALUE) > $(@D)/value\n'
        'endef\n'
        '\n'
        'define REBUILD_TEST_INSTALL_TARGET_CMDS\n'
        '\t$(INSTALL) -m 0644 $(@D)/value $(TARGET_DIR)/opt/rebuild-test-value\n'
        'endef\n'
        '\n'
        '$(eval $(generic-package))\n',
}


class TestRebuildChangedPackagesBase(infra.basetest.BRConfigTest):
    """Check BR2_REBUILD_CHANGED_PACKAGES. pciutils uses zlib only when
    it is enabled, zlib is a virtual package provided by libzlib, and
    rebuild-test, from a br2-external tree made by the test, is built
    against pciutils. Each change below must rebuild exactly the
    expected packages, remove the files of the removed ones from the
    target and staging directories, and leave nothing stale."""
    config = infra.basetest.BASIC_TOOLCHAIN_CONFIG + \
        infra.basetest.MINIMAL_CONFIG + \
        """
        BR2_REBUILD_CHANGED_PACKAGES=y
        BR2_PACKAGE_PCIUTILS=y
        BR2_PACKAGE_REBUILD_TEST=y
        """

    def __init__(self, names):
        super(TestRebuildChangedPackagesBase, self).__init__(names)
        # Outside of the build directory, that is removed by setUp(), as
        # they must exist when configuring.
        self.patchdir = self.builddir and self.builddir + "-patches"
        self.external = self.builddir and self.builddir + "-external"
        self.br2_external = [self.external]
        self.config += '\nBR2_GLOBAL_PATCH_DIR="{}"\n'.format(self.patchdir)

    def setUp(self):
        shutil.rmtree(self.patchdir, ignore_errors=True)
        shutil.rmtree(self.external, ignore_errors=True)
        os.makedirs(self.patchdir)
        for path, content in EXTERNAL.items():
            os.makedirs(os.path.dirname(os.path.join(self.external, path)), exist_ok=True)
            with open(os.path.join(self.external, path), "w") as f:
                f.write(content)
        super(TestRebuildChangedPackagesBase, self).setUp()

    def tearDown(self):
        super(TestRebuildChangedPackagesBase, self).tearDown()
        shutil.rmtree(self.patchdir, ignore_errors=True)
        shutil.rmtree(self.external, ignore_errors=True)

    # Helpers

    def path(self, *p):
        return os.path.join(self.builddir, *p)

    def reconfigure(self, config):
        self.b.config = "\n".join(line.lstrip() for line in config.splitlines()) + "\n"
        self.b.configure()

    def make(self, *args):
        # Same environment as the builds: with output/host/bin in PATH,
        # the host tools found would not be the same.
        env = {"PATH": os.environ["PATH"], "HOME": os.environ["HOME"]}
        return subprocess.check_output(["make", "-s", "-C", self.builddir] + list(args),
                                       env=env, text=True)

    def show_stale(self):
        return self.make("show-stale")

    def build_dir(self, name):
        """The build directory of a package, from its build record."""
        for record in glob.glob(self.path("build", "*", ".stamp_build_record")):
            build = os.path.dirname(record)
            with open(record) as f:
                if "BUILD_RECORD_NAME_%s = %s\n" % (os.path.basename(build), name) in f.read():
                    return build
        return None

    def configured_at(self, name):
        build = self.build_dir(name)
        self.assertTrue(build, "no build record for %s" % name)
        return os.path.getmtime(os.path.join(build, ".stamp_configured"))

    def build(self, rebuilt, kept, *args):
        """Build, and check that the packages in rebuilt were configured
        again, and those in kept were not, and that nothing is stale."""
        time.sleep(1)
        start = time.time()
        self.b.build(make_extra_opts=list(args))
        for name in rebuilt:
            self.assertGreater(self.configured_at(name), start, "%s not rebuilt" % name)
        for name in kept:
            self.assertLess(self.configured_at(name), start, "%s rebuilt" % name)
        self.assertIn("Nothing to rebuild or remove", self.show_stale())

    def assert_stale(self, rebuild, remove=[], not_stale=[]):
        """Check the output of show-stale: the packages to rebuild and to
        remove (with the reason), and packages that must not be stale."""
        stale = self.show_stale()
        to_rebuild, _, to_remove = stale.partition("Packages to remove:")
        for line in rebuild:
            self.assertIn("  " + line + "\n", to_rebuild)
        for line in remove:
            self.assertIn("  " + line + "\n", to_remove)
        for name in not_stale:
            self.assertNotIn("  " + name + " ", stale)
        return stale

    def pciutils_needed(self):
        """The shared libraries pciutils is linked against."""
        readelf = glob.glob(self.path("host/bin/*-readelf"))[0]
        needed = set()
        for f in glob.glob(self.path("target/usr/lib/libpci.so*")):
            out = infra.run_cmd_on_host(self.builddir, [readelf, "-d", f])
            needed.update(line.split("[")[1].rstrip("]")
                          for line in out.splitlines() if "(NEEDED)" in line)
        self.assertTrue(needed)
        return needed

    def listed_files(self, name, file_list):
        with open(os.path.join(self.build_dir(name), file_list)) as f:
            return [line.rstrip("\n").partition(",")[2] for line in f]

    def libzlib_patched(self):
        return os.path.exists(os.path.join(self.build_dir("libzlib"), "buildroot-rebuild-test.txt"))

    def rebuild_test_value(self):
        with open(self.path("target/opt/rebuild-test-value")) as f:
            return f.read().strip()

    def marker(self):
        return self.path("target/rebuild-test-marker")

    # Scenario, run by the test classes below

    def run_scenario(self):
        base = ["toolchain", "toolchain-external-bootlin", "skeleton", "host-skeleton"]
        config_zlib = self.config + "\nBR2_PACKAGE_ZLIB=y\n"
        config_zlib_os = config_zlib + "\nBR2_OPTIMIZE_S=y\n"
        config_os = self.config + "\nBR2_OPTIMIZE_S=y\n"
        mk = os.path.join(self.external, "package/rebuild-test/rebuild-test.mk")

        # Build without zlib. A file no package installed in the target
        # directory must be kept, as it is cleaned using the file lists
        # of the packages, not re-created.
        self.b.build()
        self.assertNotIn("libz.so.1", self.pciutils_needed())
        self.assertEqual(self.rebuild_test_value(), "1")
        self.assertIn("Nothing to rebuild or remove", self.show_stale())
        open(self.marker(), "w").close()

        # Enabling zlib changes how pciutils is built, and rebuild-test
        # is built against pciutils
        self.reconfigure(config_zlib)
        self.assert_stale(["pciutils (configuration changed)",
                           "rebuild-test (built against pciutils)"])
        self.build(["pciutils", "libzlib", "zlib", "rebuild-test"], base)
        self.assertIn("libz.so.1", self.pciutils_needed())
        self.assertTrue(os.path.exists(self.path("staging/usr/include/zlib.h")))
        self.assertTrue(os.path.exists(self.marker()))

        # A variable of rebuild-test changed in its .mk file only
        # rebuilds rebuild-test, then again when the change is reverted
        with open(mk) as f:
            content = f.read()
        with open(mk, "w") as f:
            f.write(content.replace("REBUILD_TEST_VALUE = 1", "REBUILD_TEST_VALUE = 2"))
        self.assert_stale(["rebuild-test (configuration changed)"],
                          not_stale=["pciutils", "libzlib", "zlib"])
        self.build(["rebuild-test"], base + ["pciutils", "libzlib", "zlib"])
        self.assertEqual(self.rebuild_test_value(), "2")
        with open(mk, "w") as f:
            f.write(content)
        self.assert_stale(["rebuild-test (configuration changed)"])
        self.build(["rebuild-test"], base + ["pciutils", "libzlib", "zlib"])
        self.assertEqual(self.rebuild_test_value(), "1")

        # Adding a patch to libzlib rebuilds it, and the packages built
        # against it, and so does removing it
        patch = os.path.join(self.patchdir, "libzlib", "0001-rebuild-test.patch")
        os.makedirs(os.path.dirname(patch))
        with open(patch, "w") as f:
            f.write(TEST_PATCH)
        self.assert_stale(["libzlib (configuration changed)",
                           "pciutils (built against zlib)",
                           "rebuild-test (built against pciutils)",
                           "zlib (built against libzlib)"])
        self.build(["libzlib", "zlib", "pciutils", "rebuild-test"], base)
        self.assertTrue(self.libzlib_patched())
        os.remove(patch)
        self.assert_stale(["libzlib (configuration changed)"])
        self.build(["libzlib", "zlib", "pciutils", "rebuild-test"], base)
        self.assertFalse(self.libzlib_patched())

        # A global option used by the commands of the target packages
        # rebuilds them, but not the host packages
        self.reconfigure(config_zlib_os)
        self.assert_stale(["libzlib (configuration changed)", "pciutils (configuration changed)"],
                          not_stale=["host-skeleton"])
        self.build(["libzlib", "pciutils"], ["host-skeleton"])

        # <pkg>-remove rebuilds the package and the packages built
        # against it
        self.build(["libzlib", "zlib", "pciutils", "rebuild-test"], base, "libzlib-remove")

        # In verbose mode, show-stale writes the current text of each
        # package next to its record
        self.make("V=1", "show-stale")
        self.assertTrue(os.path.exists(os.path.join(self.build_dir("pciutils"),
                                                    ".stamp_build_record.verbose.new")))

        # Disabling zlib removes libzlib, and all its files from the
        # target and staging directories, and rebuilds pciutils
        libzlib_target = self.listed_files("libzlib", ".files-list.txt")
        libzlib_staging = self.listed_files("libzlib", ".files-list-staging.txt")
        self.assertTrue(libzlib_target)
        self.assertTrue(libzlib_staging)
        self.reconfigure(config_os)
        self.assert_stale(["pciutils (configuration changed)", "rebuild-test (built against pciutils)"],
                          ["libzlib (no longer enabled)", "zlib (no longer enabled)"])
        self.build(["pciutils", "rebuild-test"], base)
        self.assertNotIn("libz.so.1", self.pciutils_needed())
        for f in libzlib_target:
            self.assertFalse(os.path.lexists(self.path("target", f)), f)
        for f in libzlib_staging:
            self.assertFalse(os.path.lexists(self.path("staging", f)), f)
        self.assertTrue(os.path.exists(self.marker()))

        # Without the file list of a removed package, the target
        # directory is re-created instead
        self.reconfigure(config_zlib_os)
        self.build(["pciutils", "libzlib", "zlib", "rebuild-test"], base)
        os.remove(os.path.join(self.build_dir("libzlib"), ".files-list.txt"))
        self.reconfigure(config_os)
        self.assertIn("The target directory will be re-created", self.show_stale())
        self.build(["pciutils", "rebuild-test"], base)
        self.assertFalse(os.path.exists(self.marker()))
        self.assertFalse(glob.glob(self.path("target/usr/lib/libz.so*")))
        self.assertTrue(glob.glob(self.path("target/usr/lib/libpci.so*")))
        self.assertEqual(self.rebuild_test_value(), "1")


class TestRebuildChangedPackages(TestRebuildChangedPackagesBase):
    def test_run(self):
        self.run_scenario()


class TestRebuildChangedPackagesPerPackage(TestRebuildChangedPackagesBase):
    config = TestRebuildChangedPackagesBase.config + \
        """
        BR2_PER_PACKAGE_DIRECTORIES=y
        """

    def test_run(self):
        self.run_scenario()

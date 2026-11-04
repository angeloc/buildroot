import glob
import hashlib
import os
import shutil
import time

import infra.basetest

POST_BUILD = """#!/bin/sh
echo post-build > "$1/etc/target-reinstall-post-build"
"""


class TestTargetReinstallBase(infra.basetest.BRConfigTest):
    """Check that 'make target-reinstall' re-creates the target
    directory from what the enabled packages install, the root
    filesystem overlay and the post-build script, without rebuilding
    any package."""
    config = infra.basetest.BASIC_TOOLCHAIN_CONFIG + \
        infra.basetest.MINIMAL_CONFIG + \
        """
        BR2_PACKAGE_PCIUTILS=y
        BR2_PACKAGE_BZIP2=y
        """

    def __init__(self, names):
        super(TestTargetReinstallBase, self).__init__(names)
        # Outside of the build directory, that is removed by setUp()
        self.overlay = self.builddir and self.builddir + "-overlay"
        self.post_build = self.builddir and self.builddir + "-post-build.sh"
        self.config += '\nBR2_ROOTFS_OVERLAY="{}"\n'.format(self.overlay)
        self.config += '\nBR2_ROOTFS_POST_BUILD_SCRIPT="{}"\n'.format(self.post_build)

    def setUp(self):
        shutil.rmtree(self.overlay, ignore_errors=True)
        os.makedirs(os.path.join(self.overlay, "etc"))
        for name in ["target-reinstall-overlay", "target-reinstall-overlay-removed"]:
            with open(os.path.join(self.overlay, "etc", name), "w") as f:
                f.write(name + "\n")
        with open(self.post_build, "w") as f:
            f.write(POST_BUILD)
        os.chmod(self.post_build, 0o755)
        super(TestTargetReinstallBase, self).setUp()

    def tearDown(self):
        super(TestTargetReinstallBase, self).tearDown()
        shutil.rmtree(self.overlay, ignore_errors=True)
        if os.path.exists(self.post_build):
            os.remove(self.post_build)

    # Helpers

    def path(self, *p):
        return os.path.join(self.builddir, *p)

    def ppd(self):
        return "BR2_PER_PACKAGE_DIRECTORIES=y" in self.b.config.splitlines()

    def stamps(self, stamp):
        """The time of a stamp file, for each build directory."""
        return {os.path.basename(os.path.dirname(s)): os.path.getmtime(s)
                for s in glob.glob(self.path("build", "*", stamp))}

    def file_list(self):
        with open(self.path("build", "packages-file-list.txt")) as f:
            return f.read()

    def target_tree(self):
        """The files of the target directory, with their content (or
        the target of the symbolic links), but not their times."""
        tree = {}
        root = self.path("target")
        for d, dirs, files in os.walk(root):
            for name in files + [x for x in dirs if os.path.islink(os.path.join(d, x))]:
                p = os.path.join(d, name)
                rel = os.path.relpath(p, root)
                if os.path.islink(p):
                    tree[rel] = "-> " + os.readlink(p)
                else:
                    with open(p, "rb") as f:
                        tree[rel] = hashlib.sha256(f.read()).hexdigest()
        return tree

    def pciutils_file(self):
        """A regular file installed by pciutils in the target directory."""
        with open(glob.glob(self.path("build/pciutils-*/.files-list.txt"))[0]) as f:
            for line in f:
                rel = line.rstrip("\n").partition(",")[2]
                if os.path.isfile(self.path("target", rel)) and \
                   not os.path.islink(self.path("target", rel)):
                    return self.path("target", rel)
        self.fail("no file installed by pciutils")

    def target_reinstall(self, *targets):
        """Run the targets, and check that no package was configured or
        built again."""
        configured = self.stamps(".stamp_configured")
        built = self.stamps(".stamp_built")
        self.b.build(make_extra_opts=list(targets))
        self.assertEqual(self.stamps(".stamp_configured"), configured)
        self.assertEqual(self.stamps(".stamp_built"), built)

    # Scenario, run by the test classes below

    def run_scenario(self):
        self.b.build()
        self.assertTrue(os.path.exists(self.path("target/usr/bin/bzip2")))
        self.assertTrue(os.path.exists(self.path("target/etc/target-reinstall-overlay")))
        self.assertTrue(os.path.exists(self.path("target/etc/target-reinstall-post-build")))
        self.assertIn("pciutils,", self.file_list())
        self.assertIn("bzip2,", self.file_list())

        # Disabling bzip2, or removing a file from the overlay, does not
        # remove them from the target directory
        config = "\n".join(line.lstrip() for line in self.b.config.splitlines()
                           if "BR2_PACKAGE_BZIP2" not in line)
        self.b.config = config + "\n"
        self.b.configure()
        os.remove(os.path.join(self.overlay, "etc", "target-reinstall-overlay-removed"))
        self.b.build()
        self.assertTrue(os.path.exists(self.path("target/usr/bin/bzip2")))
        self.assertTrue(os.path.exists(self.path("target/etc/target-reinstall-overlay-removed")))

        # A file no package installed, and a file of a package changed by
        # hand, in the target directory
        marker = self.path("target/target-reinstall-marker")
        open(marker, "w").close()
        changed = self.pciutils_file()
        with open(changed, "rb") as f:
            original = f.read()
        with open(changed, "wb") as f:
            f.write(b"changed by hand\n")

        # target-reinstall re-creates the target directory: bzip2, the
        # file removed from the overlay and the added file are gone, the
        # file changed by hand is installed again, and so are the C
        # library of the toolchain, the overlay and the files of the
        # post-build script. With per-package directories, the target
        # directory is made again from the per-package ones, without
        # installing anything
        time.sleep(1)
        start = time.time()
        self.target_reinstall("target-reinstall")
        self.assertFalse(os.path.exists(self.path("target/usr/bin/bzip2")))
        self.assertFalse(os.path.exists(self.path("target/etc/target-reinstall-overlay-removed")))
        self.assertFalse(os.path.exists(marker))
        with open(changed, "rb") as f:
            self.assertEqual(f.read(), original)
        self.assertTrue(glob.glob(self.path("target/lib/libc.so*")))
        self.assertTrue(os.path.exists(self.path("target/etc/target-reinstall-overlay")))
        self.assertTrue(os.path.exists(self.path("target/etc/target-reinstall-post-build")))
        self.assertIn("pciutils,", self.file_list())
        if not self.ppd():
            pciutils = os.path.basename(glob.glob(self.path("build/pciutils-*"))[0])
            self.assertGreater(self.stamps(".stamp_target_installed")[pciutils], start)
        tree = self.target_tree()

        # target-reinstall again gives the same target directory
        self.target_reinstall("target-reinstall")
        self.assertEqual(self.target_tree(), tree)

        # So does a build after the target directory was removed, as when
        # target-reinstall is interrupted after removing it
        self.target_reinstall("target-clean-for-reinstall")
        self.assertFalse(os.path.exists(self.path("target")))
        self.target_reinstall()
        self.assertEqual(self.target_tree(), tree)
        self.assertIn("pciutils,", self.file_list())


class TestTargetReinstall(TestTargetReinstallBase):
    def test_run(self):
        self.run_scenario()


class TestTargetReinstallPerPackage(TestTargetReinstallBase):
    config = TestTargetReinstallBase.config + \
        """
        BR2_PER_PACKAGE_DIRECTORIES=y
        """

    def test_run(self):
        self.run_scenario()

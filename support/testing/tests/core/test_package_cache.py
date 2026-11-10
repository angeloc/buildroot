import glob
import json
import os
import shutil
import stat
import subprocess
import tempfile
import unittest

import infra.basetest
from infra.builder import Builder

PACKAGE_CACHE = os.path.join(os.path.dirname(__file__), "..", "..", "..", "scripts", "package-cache")


class TestPackageCache(infra.basetest.BRConfigTest):
    """Check BR2_PACKAGE_CACHE: a second output, built with the same
    configuration and cache, restores the packages instead of building
    them, without their sources, and gets the same target directory, but
    the path of the output in the text files. legal-info gets the sources
    of the restored packages. A package whose result has the path of the
    output in a binary file is built: host-patchelf, in its RPATH,
    toolchain-external-bootlin, in its wrapper (-ffile-prefix-map, with
    BR2_REPRODUCIBLE), and libconfig, in the RPATH libtool gives its C++
    library in the staging directory. Some packages built by swupdate
    do not give the same result in two outputs (see not_reproducible):
    their files are not compared.
    Changing an option rebuilds the package, reverting it restores the
    package again. The verify mode finds no difference, as the builds
    are reproducible. swupdate, a kconfig package, is restored with its
    sources and its .config. A package built against a package rebuilt
    by hand after its key was computed is not stored."""
    config = infra.basetest.BASIC_TOOLCHAIN_CONFIG + \
        """
        BR2_REPRODUCIBLE=y
        BR2_PER_PACKAGE_DIRECTORIES=y
        BR2_REBUILD_CHANGED_PACKAGES=y
        BR2_PACKAGE_CACHE=y
        BR2_PACKAGE_DROPBEAR=y
        BR2_PACKAGE_SWUPDATE=y
        # BR2_TARGET_ROOTFS_TAR is not set
        """
    cached = ["busybox", "dropbear", "libxcrypt", "skeleton-init-sysv", "swupdate"]
    bound = ["host-patchelf", "toolchain-external-bootlin", "libconfig"]
    # Packages whose result differs from one output to another, even with
    # BR2_REPRODUCIBLE: libconfig (build ID, as it is built again),
    # libubootenv (order of the symbol versions of fw_printenv), libzlib
    # and json-c (time of the build in the symbol index of their static
    # libraries, written by ar)
    not_reproducible = ["libconfig", "libubootenv", "libzlib", "json-c"]

    def __init__(self, names):
        super(TestPackageCache, self).__init__(names)
        self.cachedir = self.builddir and self.builddir + "-cache"
        self.config += '\nBR2_PACKAGE_CACHE_DIR="{}"\n'.format(self.cachedir)
        self.builders = []

    def setUp(self):
        shutil.rmtree(self.cachedir, ignore_errors=True)
        super(TestPackageCache, self).setUp()

    def tearDown(self):
        if not self.keepbuilds:
            for b in self.builders:
                b.delete()
            shutil.rmtree(self.cachedir, ignore_errors=True)
        super(TestPackageCache, self).tearDown()

    def builder(self, suffix, config="", cachedir=None):
        """Another output, configured, with another cache directory if
        given"""
        base = self.config
        if cachedir:
            base = base.replace('BR2_PACKAGE_CACHE_DIR="{}"'.format(self.cachedir),
                                'BR2_PACKAGE_CACHE_DIR="{}"'.format(cachedir))
        b = Builder(base + "\n" + config, self.builddir + suffix, self.logtofile, self.jlevel)
        b.delete()
        b.configure()
        self.builders.append(b)
        return b

    @staticmethod
    def build_dir(b, name):
        """The build directory of a package"""
        for d in glob.glob(os.path.join(b.builddir, "build", name + "*")):
            if os.path.basename(d) == name or \
               os.path.basename(d)[len(name) + 1:][:1].isdigit():
                return d
        return None

    def restored(self, b, name):
        return os.path.exists(os.path.join(self.build_dir(b, name), ".stamp_cache_restored"))

    def tree(self, b):
        """The target directory, with the path of the output replaced in
        the files, without the files of the packages not compared"""
        root = os.path.join(b.builddir, "target")
        skip = set()
        for name in self.not_reproducible:
            with open(os.path.join(self.build_dir(b, name), ".files-list.txt")) as f:
                skip.update(os.path.normpath(line.rstrip("\n").partition(",")[2]) for line in f)
        entries = {}
        for d, dirs, files in os.walk(root):
            for name in dirs + files:
                p = os.path.join(d, name)
                st = os.lstat(p)
                if stat.S_ISLNK(st.st_mode):
                    entries[os.path.relpath(p, root)] = ("link", os.readlink(p))
                elif stat.S_ISDIR(st.st_mode):
                    entries[os.path.relpath(p, root)] = ("dir", stat.S_IMODE(st.st_mode))
                else:
                    with open(p, "rb") as f:
                        data = f.read().replace(b.builddir.encode(), b"@BASE_DIR@")
                    entries[os.path.relpath(p, root)] = ("file", stat.S_IMODE(st.st_mode), data)
        return {p: e for p, e in entries.items() if p not in skip}

    def test_run(self):
        # The first output builds all the packages and stores them
        self.b.build()
        for name in self.cached + self.bound:
            self.assertFalse(self.restored(self.b, name), name)
            self.assertTrue(glob.glob(os.path.join(self.cachedir, name, "*", "manifest.json")), name)

        # The second output restores them
        b2 = self.builder("-2")
        b2.build()
        for name in self.cached:
            self.assertTrue(self.restored(b2, name), name)
        for name in self.bound:
            self.assertFalse(self.restored(b2, name), name)
        self.assertEqual(self.tree(self.b), self.tree(b2))
        dropbear = self.build_dir(b2, "dropbear")
        self.assertFalse(os.path.exists(os.path.join(dropbear, "configure")))

        # A kconfig package is restored with its sources and its .config,
        # used by its configuration editors and update targets
        configs = []
        for b in (self.b, b2):
            with open(os.path.join(self.build_dir(b, "swupdate"), ".config")) as f:
                configs.append(f.read())
        self.assertEqual(configs[0], configs[1])

        # legal-info downloads, extracts and patches them
        b2.build(make_extra_opts=["legal-info"])
        self.assertTrue(os.path.exists(os.path.join(dropbear, "configure")))
        self.assertTrue(glob.glob(os.path.join(b2.builddir, "legal-info", "licenses",
                                               "dropbear-*", "LICENSE")))
        b2.build()
        self.assertTrue(self.restored(b2, "dropbear"))
        self.assertEqual(self.tree(self.b), self.tree(b2))

        # Changing an option builds the package, reverting it restores
        # it again
        b2.config = self.b.config + "\n# BR2_PACKAGE_DROPBEAR_CLIENT is not set\n"
        b2.configure()
        b2.build()
        self.assertFalse(self.restored(b2, "dropbear"))
        self.assertFalse(os.path.exists(os.path.join(b2.builddir, "target/usr/bin/dbclient")))
        b2.config = self.b.config
        b2.configure()
        b2.build()
        self.assertTrue(self.restored(b2, "dropbear"))
        self.assertEqual(self.tree(self.b), self.tree(b2))

        # Installing a restored package again looks it up again
        b2.build(make_extra_opts=["dropbear-reinstall"])
        self.assertTrue(self.restored(b2, "dropbear"))
        self.assertEqual(self.tree(self.b), self.tree(b2))

        # A package rebuilt by hand is built, and not restored nor
        # stored any more
        entries = glob.glob(os.path.join(self.cachedir, "dropbear", "*"))
        b2.build(make_extra_opts=["dropbear-rebuild"])
        dropbear = self.build_dir(b2, "dropbear")
        self.assertFalse(self.restored(b2, "dropbear"))
        self.assertTrue(os.path.exists(os.path.join(dropbear, ".stamp_cache_dirty")))
        self.assertTrue(os.path.exists(os.path.join(dropbear, "Makefile")))
        self.assertEqual(entries, glob.glob(os.path.join(self.cachedir, "dropbear", "*")))

        # A restored package reconfigured by hand is built from its
        # sources
        b2.build(make_extra_opts=["libxcrypt-reconfigure"])
        libxcrypt = self.build_dir(b2, "libxcrypt")
        self.assertFalse(self.restored(b2, "libxcrypt"))
        self.assertTrue(os.path.exists(os.path.join(libxcrypt, "Makefile")))

        # The verify mode builds the packages, and finds the same result
        b3 = self.builder("-3", "\nBR2_PACKAGE_CACHE_VERIFY=y\n")
        b3.build()
        for name in self.cached:
            self.assertFalse(self.restored(b3, name), name)
        report = os.path.join(b3.builddir, "package-cache-verify.txt")
        if os.path.exists(report):
            with open(report) as f:
                self.assertEqual([line for line in f
                                  if line.partition(":")[0] not in self.not_reproducible], [])
        self.assertEqual(self.tree(self.b), self.tree(b3))

        # With its own cache: dropbear gets its key, then libxcrypt, which
        # it is built against, is rebuilt by hand, so dropbear is not
        # stored, and loses its key. Nor is busybox, also built against
        # libxcrypt; skeleton-init-sysv is stored
        cache4 = self.cachedir + "-4"
        shutil.rmtree(cache4, ignore_errors=True)
        b4 = self.builder("-4", cachedir=cache4)
        b4.build(make_extra_opts=["dropbear-source"])
        dropbear = self.build_dir(b4, "dropbear")
        self.assertTrue(os.path.exists(os.path.join(dropbear, ".cache_key")))
        b4.build(make_extra_opts=["libxcrypt-rebuild"])
        b4.build()
        self.assertFalse(os.path.exists(os.path.join(dropbear, ".cache_key")))
        self.assertFalse(glob.glob(os.path.join(cache4, "dropbear", "*")))
        self.assertFalse(glob.glob(os.path.join(cache4, "busybox", "*")))
        self.assertTrue(glob.glob(os.path.join(cache4, "skeleton-init-sysv", "*", "manifest.json")))
        if not self.keepbuilds:
            shutil.rmtree(cache4, ignore_errors=True)


class TestPackageCacheExternalToolchain(TestPackageCache):
    """The external toolchain is installed in the host directory when it
    is extracted, before the snapshot of its result: without
    BR2_REPRODUCIBLE, its wrapper has no path of the output, so it is
    restored in a second output, and it must then be extracted again. The
    second output builds json-c, not in the cache, with it."""
    config = infra.basetest.BASIC_TOOLCHAIN_CONFIG + \
        """
        BR2_PER_PACKAGE_DIRECTORIES=y
        BR2_PACKAGE_CACHE=y
        BR2_PACKAGE_ZLIB=y
        BR2_PACKAGE_LIBZLIB=y
        # BR2_TARGET_ROOTFS_TAR is not set
        """

    def test_run(self):
        self.b.build()
        b2 = self.builder("-2", "BR2_PACKAGE_JSON_C=y")
        b2.build()
        self.assertTrue(self.restored(b2, "toolchain-external-bootlin"))
        self.assertTrue(self.restored(b2, "libzlib"))
        self.assertFalse(self.restored(b2, "json-c"))
        self.assertTrue(glob.glob(os.path.join(b2.builddir, "target/usr/lib/libjson-c.so*")))


class TestPackageCacheScript(unittest.TestCase):
    """Check support/scripts/package-cache alone: an entry whose text
    files contain a path of the build (here, of a br2-external tree) is
    only found where that path exists; it is compressed with zstd with
    Python 3.14 or later, else with gzip; it is restored with the paths
    of the new build."""

    def run_script(self, *args):
        return subprocess.run([PACKAGE_CACHE] + list(args), check=True,
                              capture_output=True, text=True).stdout

    def test_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "root")
            os.makedirs(root)
            ext = os.path.join(tmp, "external")
            cache = os.path.join(tmp, "cache")
            snapshot = os.path.join(tmp, "snapshot")
            self.run_script("snapshot", "--root", "target=" + root, "--output", snapshot)
            with open(os.path.join(root, "foo.pc"), "w") as f:
                f.write("prefix=%s/usr\n" % ext)
            common = ["--cache-dir", cache, "--name", "foo", "--key", "k"]
            self.run_script("store", *common, "--root", "target=" + root, "--snapshot", snapshot,
                            "--path", "BASE_DIR=" + tmp, "--path", "BR2_EXTERNAL_FOO_PATH=" + ext)
            with open(os.path.join(cache, "foo", "k", "manifest.json")) as f:
                self.assertEqual(json.load(f)["used"], ["BR2_EXTERNAL_FOO_PATH"])
            self.assertTrue(self.run_script("lookup", *common, "--path", "BASE_DIR=" + tmp,
                                            "--path", "BR2_EXTERNAL_FOO_PATH=" + ext))
            self.assertFalse(self.run_script("lookup", *common, "--path", "BASE_DIR=" + tmp))

            # The archives are compressed with zstd with Python 3.14 or
            # later, else with gzip
            zstd = subprocess.run(["python3", "-c", "import sys; print(sys.version_info >= (3, 14))"],
                                  check=True, capture_output=True, text=True).stdout.strip() == "True"
            ext_expected = ".tar.zst" if zstd else ".tar.gz"
            self.assertTrue(os.path.exists(os.path.join(cache, "foo", "k", "target" + ext_expected)))

            # Restored in another build, with its paths replaced
            root2 = os.path.join(tmp, "root2")
            ext2 = os.path.join(tmp, "external2")
            self.run_script("restore", *common, "--root", "target=" + root2,
                            "--path", "BASE_DIR=" + tmp, "--path", "BR2_EXTERNAL_FOO_PATH=" + ext2)
            with open(os.path.join(root2, "foo.pc")) as f:
                self.assertEqual(f.read(), "prefix=%s/usr\n" % ext2)

import pytest

import os
import sys
import shutil
from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Util.FileDir import FileDir

class TestFileDir:

    def testRemoveFiles(self):
        try:
            os.mkdir(current+'/resources/count_dir/two_bis')
        except Exception:
            pass
        
        shutil.copy(
            current+'/resources/count_dir/two/one',
            current+'/resources/count_dir/two_bis'
        )
        shutil.copy(
            current+'/resources/count_dir/two/two',
            current+'/resources/count_dir/two_bis'
        )

        FileDir.removeFiles(current+'/resources/count_dir/two_bis')

        assert 0 == FileDir.countFiles(current+'/resources/count_dir/two_bis')

        os.rmdir(current+'/resources/count_dir/two_bis')
        
    def testCreateDirsOne(self):
        dirOne = 'temp/one'
        FileDir.createDirs(dirOne)

        dirOnePath = Path(dirOne)

        assert True == dirOnePath.is_dir()

        os.rmdir(dirOne)
        
    def testCreateDirsMany(self):
        dir = 'temp/one/two/three'
        FileDir.createDirs(dir)

        dirPath = Path(dir)

        assert True == dirPath.is_dir()

        os.rmdir(dirPath)
        
    def testCreateDirsMultiple(self):
        dirs = 'temp/one/two/three'
        FileDir.createDirs(dirs)
        FileDir.createDirs(dirs)

        dirsPath = Path(dirs)

        assert True == dirsPath.is_dir()

        os.rmdir('temp/one/two/three')
        os.rmdir('temp/one/two')
        os.rmdir('temp/one')

    def testRemoveDir(self):
        try:
            os.mkdir(current+'/resources/count_dir/two_bis')
        except Exception:
            pass
        
        shutil.copy(
            current+'/resources/count_dir/two/one',
            current+'/resources/count_dir/two_bis'
        )
        shutil.copy(
            current+'/resources/count_dir/two/two',
            current+'/resources/count_dir/two_bis'
        )

        FileDir.removeDir(current+'/resources/count_dir/two_bis')

        assert False == Path(current+'/resources/count_dir/two_bis').is_dir()
import os
import sys
import shutil
from pathlib import Path

current = os.path.dirname(os.path.realpath(__file__))
parent = os.path.dirname(current)
sys.path.append(parent)

from module.Util.FileDir import FileDir

class TestFileDir:
    def testCountFiles(self):
        assert 2 == FileDir.countFiles('tests/resources/count_dir/two')
        assert 4 == FileDir.countFiles('tests/resources/count_dir/four')

    def testCountFilesWithExtension(self):
        assert 3 == FileDir.countFiles('tests/resources/count_dir/extensions')

        assert 0 == FileDir.countFilesWithExtension('tests/resources/count_dir/extensions', 'txt')

        assert 2 == FileDir.countFilesWithExtension('tests/resources/count_dir/extensions', '.txt')
        assert 1 == FileDir.countFilesWithExtension('tests/resources/count_dir/extensions', '.md')

    def testRemoveFiles(self):
        try:
            os.mkdir('tests/resources/count_dir/two_bis')
        except Exception:
            pass
        
        shutil.copy(
            'tests/resources/count_dir/two/one',
            'tests/resources/count_dir/two_bis'
        )
        shutil.copy(
            'tests/resources/count_dir/two/two',
            'tests/resources/count_dir/two_bis'
        )

        FileDir.removeFiles('tests/resources/count_dir/two_bis')

        assert 0 == FileDir.countFiles('tests/resources/count_dir/two_bis')

        os.rmdir('tests/resources/count_dir/two_bis')
        
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
            os.mkdir('tests/resources/count_dir/two_bis')
        except Exception:
            pass
        
        shutil.copy(
            'tests/resources/count_dir/two/one',
            'tests/resources/count_dir/two_bis'
        )
        shutil.copy(
            'tests/resources/count_dir/two/two',
            'tests/resources/count_dir/two_bis'
        )

        FileDir.removeDir('tests/resources/count_dir/two_bis')

        assert False == Path('tests/resources/count_dir/two_bis').is_dir()